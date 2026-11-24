require "test_helper"

# One test per row of the permission table in CLAUDE.md
class Api::ArticlesControllerTest < ActionDispatch::IntegrationTest
  def titles
    response.parsed_body.map { |a| a["title"] }.sort
  end

  def valid_article
    { article: { title: "New one", body: "At least ten characters" } }
  end

  # --- Reading ---

  test "guest list shows only public articles" do
    get "/api/articles"
    assert_equal ["Public post"], titles
  end

  test "member list adds private articles" do
    get "/api/articles", headers: auth(users(:bob))
    assert_equal ["Private post", "Public post"], titles
  end

  test "author list adds their own archived articles" do
    get "/api/articles", headers: auth(users(:alice))
    assert_equal 3, titles.size
  end

  test "admin list shows everything" do
    get "/api/articles", headers: auth(users(:admin))
    assert_equal 3, titles.size
  end

  test "list is newest first" do
    articles(:private_post).update_column(:created_at, 1.minute.from_now)
    get "/api/articles", headers: auth(users(:bob))
    assert_equal "Private post", response.parsed_body.first["title"]
  end

  test "author info has only id, name, avatar and the deleted flag" do
    get "/api/articles"
    assert_equal %w[avatar_url deleted id name], response.parsed_body.first["user"].keys.sort
    assert_not_includes response.body, "alice@example.com"
    assert_not_includes response.body, "password_digest"
    assert_not_includes response.body, "alice-token"
  end

  test "guest opening a private article gets 404, as if it did not exist" do
    get "/api/articles/#{articles(:private_post).id}"
    assert_response :not_found
  end

  test "member opening someone else's archived article gets 404" do
    get "/api/articles/#{articles(:archived_post).id}", headers: auth(users(:bob))
    assert_response :not_found
  end

  test "author and admin can open the archived article" do
    get "/api/articles/#{articles(:archived_post).id}", headers: auth(users(:alice))
    assert_response :ok
    get "/api/articles/#{articles(:archived_post).id}", headers: auth(users(:admin))
    assert_response :ok
  end

  test "list sends a summary and a thumbnail, never the whole body" do
    articles(:public_post).update!(body: "<p>Hello &amp; welcome to this post</p><p><img src=\"/api/files/a.png\"></p>")
    get "/api/articles"
    item = response.parsed_body.first
    assert_not item.key?("body")
    assert_equal "Hello & welcome to this post", item["excerpt"]
    assert_equal "/api/files/a.png", item["cover_image"]
    assert_equal 2, item["comments_count"]
  end

  test "member sees the whole article with its comments" do
    get "/api/articles/#{articles(:public_post).id}", headers: auth(users(:bob))
    assert_equal 2, response.parsed_body["comments"].size
    assert_equal false, response.parsed_body["truncated"]
  end

  test "guest gets only the beginning of a long article and no comments" do
    articles(:public_post).update!(body: "<p>#{"a" * 250}</p><p>#{"b" * 250}</p><p>secret ending</p>")
    get "/api/articles/#{articles(:public_post).id}"
    json = response.parsed_body
    assert_equal true, json["truncated"]
    assert_not json.key?("comments")
    assert_equal 2, json["comments_count"]
    assert_includes json["body"], "a" * 250
    assert_not_includes json["body"], "secret ending"
    assert_not_includes response.body, "secret ending"
  end

  test "guest reads a short article in full" do
    get "/api/articles/#{articles(:public_post).id}"
    assert_equal false, response.parsed_body["truncated"]
    assert_includes response.parsed_body["body"], "Everyone can read this article."
  end

  test "anonymous comments hide their writer from everyone, admins included" do
    articles(:public_post).comments.create!(user: users(:bob), commenter: "Bob", body: "Psst", anonymous: true)
    [users(:alice), users(:admin)].each do |viewer|
      get "/api/articles/#{articles(:public_post).id}", headers: auth(viewer)
      anon = response.parsed_body["comments"].find { |c| c["anonymous"] }
      assert_nil anon["commenter"]
      assert_nil anon["user_id"]
      assert_equal viewer.admin?, anon["can_destroy"] # admin may delete, the article author may not
    end
  end

  test "the anonymous writer can still delete their own comment" do
    articles(:public_post).comments.create!(user: users(:bob), commenter: "Bob", body: "Psst", anonymous: true)
    get "/api/articles/#{articles(:public_post).id}", headers: auth(users(:bob))
    assert response.parsed_body["comments"].find { |c| c["anonymous"] }["can_destroy"]
  end

  # --- Creating ---

  test "guest cannot create" do
    assert_no_difference("Article.count") { post "/api/articles", params: valid_article }
    assert_response :unauthorized
  end

  test "member creates an article owned by them, public by default" do
    post "/api/articles", params: valid_article, headers: auth(users(:bob))
    assert_response :created
    article = Article.last
    assert_equal users(:bob), article.user
    assert_equal "public", article.status
  end

  test "invalid article returns errors per field" do
    post "/api/articles", params: { article: { title: "", body: "short", status: "secret" } }, headers: auth(users(:bob))
    assert_response :unprocessable_content
    assert_equal %w[body status title], response.parsed_body.keys.sort
  end

  test "cannot create an article in someone else's name" do
    post "/api/articles", params: { article: { title: "Fake", body: "At least ten characters", user_id: users(:alice).id } }, headers: auth(users(:bob))
    assert_equal users(:bob), Article.last.user
  end

  # --- Updating ---

  test "author can edit" do
    patch "/api/articles/#{articles(:public_post).id}", params: { article: { title: "Edited" } }, headers: auth(users(:alice))
    assert_response :ok
    assert_equal "Edited", articles(:public_post).reload.title
  end

  test "author gets validation errors when editing" do
    patch "/api/articles/#{articles(:public_post).id}", params: { article: { title: "" } }, headers: auth(users(:alice))
    assert_response :unprocessable_content
  end

  test "other member cannot edit" do
    patch "/api/articles/#{articles(:public_post).id}", params: { article: { title: "Hacked" } }, headers: auth(users(:bob))
    assert_response :forbidden
  end

  test "admin cannot edit either" do
    patch "/api/articles/#{articles(:public_post).id}", params: { article: { title: "Hacked" } }, headers: auth(users(:admin))
    assert_response :forbidden
  end

  test "guest cannot edit" do
    patch "/api/articles/#{articles(:public_post).id}", params: { article: { title: "Hacked" } }
    assert_response :unauthorized
  end

  # --- Deleting ---

  test "other member cannot delete" do
    assert_no_difference("Article.count") do
      delete "/api/articles/#{articles(:public_post).id}", headers: auth(users(:bob))
    end
    assert_response :forbidden
  end

  test "author can delete, and the comments go with it" do
    assert_difference("Article.count", -1) do
      assert_difference("Comment.count", -2) do
        delete "/api/articles/#{articles(:public_post).id}", headers: auth(users(:alice))
      end
    end
    assert_response :no_content
  end

  test "admin can delete any article" do
    assert_difference("Article.count", -1) do
      delete "/api/articles/#{articles(:archived_post).id}", headers: auth(users(:admin))
    end
  end

  test "guest cannot delete" do
    delete "/api/articles/#{articles(:public_post).id}"
    assert_response :unauthorized
  end
end
