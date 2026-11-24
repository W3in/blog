require "test_helper"

# Replies, hearts and notifications
class Api::SocialTest < ActionDispatch::IntegrationTest
  setup { @article = articles(:public_post) } # written by Alice; Bob and Alice commented on it

  def comment(user, body, parent: nil, anonymous: false)
    post "/api/articles/#{@article.id}/comments",
      params: { comment: { body: body, parent_id: parent&.id, anonymous: anonymous } }, headers: auth(user)
    Comment.find_by(id: response.parsed_body["id"])
  end

  def show_as(user)
    get "/api/articles/#{@article.id}", headers: auth(user)
    response.parsed_body
  end

  # --- replies ---

  test "a reply keeps its parent_id and shows in the article" do
    reply = comment(users(:alice), "@Bob cảm ơn", parent: comments(:bob_on_public))
    assert_response :created
    c = show_as(users(:bob))["comments"].find { |x| x["id"] == reply.id }
    assert_equal comments(:bob_on_public).id, c["parent_id"]
  end

  test "cannot reply to a comment of another article" do
    other = articles(:private_post).comments.create!(user: users(:bob), commenter: "Bob", body: "Elsewhere")
    comment(users(:alice), "wrong place", parent: other)
    assert_response :unprocessable_content
  end

  test "removing a comment with replies empties it; the replies stay" do
    reply = comment(users(:alice), "a reply", parent: comments(:bob_on_public))
    assert_no_difference("Comment.count") do
      delete "/api/articles/#{@article.id}/comments/#{comments(:bob_on_public).id}", headers: auth(users(:bob))
    end
    assert_response :no_content
    data = show_as(users(:admin))["comments"]
    removed = data.find { |x| x["id"] == comments(:bob_on_public).id }
    assert removed["deleted"]
    assert_nil removed["body"]
    assert_nil removed["commenter"]
    assert_not removed["can_destroy"]
    assert data.any? { |x| x["id"] == reply.id }

    comment(users(:admin), "reply to removed", parent: comments(:bob_on_public))
    assert_response :unprocessable_content # no new replies to a removed comment
  end

  test "removing a comment without replies deletes it" do
    assert_difference("Comment.count", -1) do
      delete "/api/articles/#{@article.id}/comments/#{comments(:alice_on_public).id}", headers: auth(users(:alice))
    end
  end

  # --- notifications ---

  test "a comment notifies the article author, a reply notifies the comment writer, never yourself" do
    assert_difference -> { users(:alice).notifications.count } => 1 do
      comment(users(:bob), "Hay quá")                                     # on Alice's article
    end
    assert_difference -> { users(:bob).notifications.count } => 1 do
      comment(users(:admin), "@Bob đồng ý", parent: comments(:bob_on_public))
    end
    assert_no_difference("Notification.count") do
      comment(users(:alice), "own article")                               # Alice on her own article
      comment(users(:bob), "own comment", parent: comments(:bob_on_public))
    end
  end

  test "notification list, unread count, mark all read" do
    comment(users(:admin), "@Bob ok", parent: comments(:bob_on_public))
    get "/api/notifications", headers: auth(users(:bob))
    body = response.parsed_body
    assert_equal 1, body["unread_count"]
    item = body["items"].first
    assert_equal "reply", item["kind"]
    assert_equal "Admin", item["actor"]["name"]
    assert_equal @article.id, item["article"]["id"]
    assert_not item["read"]

    post "/api/notifications/read", headers: auth(users(:bob))
    get "/api/notifications", headers: auth(users(:bob))
    assert_equal 0, response.parsed_body["unread_count"]
  end

  test "an anonymous reply does not reveal who wrote it in the notification" do
    comment(users(:admin), "secret", parent: comments(:bob_on_public), anonymous: true)
    get "/api/notifications", headers: auth(users(:bob))
    assert_nil response.parsed_body["items"].first["actor"]
    assert_not_includes response.body, "Admin"
  end

  test "you only see your own notifications; guests none" do
    comment(users(:bob), "for Alice")
    get "/api/notifications", headers: auth(users(:bob))
    assert_equal 0, response.parsed_body["unread_count"]
    get "/api/notifications"
    assert_response :unauthorized
  end

  # --- hearts ---

  test "heart an article: once per person, can be taken back" do
    2.times { post "/api/articles/#{@article.id}/like", headers: auth(users(:bob)) }
    assert_equal({ "likes_count" => 1, "liked" => true }, response.parsed_body)
    post "/api/articles/#{@article.id}/like", headers: auth(users(:admin))
    assert_equal 2, response.parsed_body["likes_count"]

    body = show_as(users(:bob))
    assert body["liked"]
    assert_equal 2, body["likes_count"]
    assert_not show_as(users(:alice))["liked"]

    delete "/api/articles/#{@article.id}/like", headers: auth(users(:bob))
    assert_equal({ "likes_count" => 1, "liked" => false }, response.parsed_body)
  end

  test "heart a comment, and the viewer's own hearts come back with the comments" do
    post "/api/articles/#{@article.id}/comments/#{comments(:bob_on_public).id}/like", headers: auth(users(:alice))
    assert_equal 1, response.parsed_body["likes_count"]
    mine = show_as(users(:alice))["comments"].find { |x| x["id"] == comments(:bob_on_public).id }
    theirs = show_as(users(:bob))["comments"].find { |x| x["id"] == comments(:bob_on_public).id }
    assert mine["liked"]
    assert_not theirs["liked"]
    assert_equal 1, theirs["likes_count"]
  end

  test "guests cannot heart; nobody can heart what they cannot see" do
    post "/api/articles/#{@article.id}/like"
    assert_response :unauthorized
    post "/api/articles/#{articles(:archived_post).id}/like", headers: auth(users(:bob))
    assert_response :not_found
  end

  test "the home page cards carry the heart count" do
    post "/api/articles/#{@article.id}/like", headers: auth(users(:bob))
    get "/api/articles"
    assert_equal 1, response.parsed_body.find { |a| a["id"] == @article.id }["likes_count"]
  end
end
