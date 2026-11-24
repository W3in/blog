require "test_helper"

# Public profile: GET /api/users/:id
class Api::UsersControllerTest < ActionDispatch::IntegrationTest
  def titles = response.parsed_body["articles"].map { |a| a["title"] }

  test "guest sees name, join date and public articles only, never the email" do
    get "/api/users/#{users(:alice).id}"
    assert_response :ok
    assert_equal "Alice", response.parsed_body["name"]
    assert response.parsed_body.key?("created_at")
    assert_equal ["Public post"], titles
    assert_not_includes response.body, "alice@example.com"
    assert_not_includes response.body, "alice-token"
    assert_nil response.parsed_body["articles"].first["body"] # cards only, like the home page
  end

  test "member also sees private articles, not archived ones" do
    get "/api/users/#{users(:alice).id}", headers: auth(users(:bob))
    assert_equal ["Private post", "Public post"].sort, titles.sort
  end

  test "the author and admins also see archived articles" do
    [users(:alice), users(:admin)].each do |viewer|
      get "/api/users/#{users(:alice).id}", headers: auth(viewer)
      assert_equal 3, titles.size
    end
  end

  test "unknown user is a 404" do
    get "/api/users/0"
    assert_response :not_found
  end
end
