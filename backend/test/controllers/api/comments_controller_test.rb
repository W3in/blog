require "test_helper"

class Api::CommentsControllerTest < ActionDispatch::IntegrationTest
  def comments_path(article)
    "/api/articles/#{article.id}/comments"
  end

  test "guest cannot comment" do
    post comments_path(articles(:public_post)), params: { comment: { body: "Hi" } }
    assert_response :unauthorized
  end

  test "member comments under their own name, whatever name they send" do
    post comments_path(articles(:public_post)), params: { comment: { body: "Hi", commenter: "Someone else" } }, headers: auth(users(:bob))
    assert_response :created
    comment = Comment.last
    assert_equal "Bob", comment.commenter
    assert_equal users(:bob), comment.user
  end

  test "member can comment anonymously: the answer has no name or id, the database still knows" do
    post comments_path(articles(:public_post)), params: { comment: { body: "Hi", anonymous: true } }, headers: auth(users(:bob))
    assert_response :created
    assert_nil response.parsed_body["commenter"]
    assert_nil response.parsed_body["user_id"]
    comment = Comment.last
    assert comment.anonymous
    assert_equal users(:bob), comment.user
  end

  test "comment count of the article follows creates and deletes" do
    article = articles(:public_post)
    post comments_path(article), params: { comment: { body: "Hi" } }, headers: auth(users(:bob))
    assert_equal 3, article.reload.comments_count
    delete "#{comments_path(article)}/#{comments(:bob_on_public).id}", headers: auth(users(:bob))
    assert_equal 2, article.reload.comments_count
  end

  test "empty comment is rejected" do
    post comments_path(articles(:public_post)), params: { comment: { body: "" } }, headers: auth(users(:bob))
    assert_response :unprocessable_content
    assert response.parsed_body["body"].any?
  end

  test "member can comment on a private article" do
    post comments_path(articles(:private_post)), params: { comment: { body: "Hi" } }, headers: auth(users(:bob))
    assert_response :created
  end

  test "cannot comment on an article you cannot see" do
    post comments_path(articles(:archived_post)), params: { comment: { body: "Hi" } }, headers: auth(users(:bob))
    assert_response :not_found
  end

  test "writer can delete their own comment" do
    assert_difference("Comment.count", -1) do
      delete "#{comments_path(articles(:public_post))}/#{comments(:bob_on_public).id}", headers: auth(users(:bob))
    end
    assert_response :no_content
  end

  test "article author cannot delete someone else's comment" do
    delete "#{comments_path(articles(:public_post))}/#{comments(:bob_on_public).id}", headers: auth(users(:alice))
    assert_response :forbidden
  end

  test "admin can delete any comment" do
    assert_difference("Comment.count", -1) do
      delete "#{comments_path(articles(:public_post))}/#{comments(:bob_on_public).id}", headers: auth(users(:admin))
    end
  end

  test "guest cannot delete a comment" do
    delete "#{comments_path(articles(:public_post))}/#{comments(:bob_on_public).id}"
    assert_response :unauthorized
  end

  test "comment id must belong to the article in the URL" do
    delete "#{comments_path(articles(:private_post))}/#{comments(:bob_on_public).id}", headers: auth(users(:admin))
    assert_response :not_found
  end
end
