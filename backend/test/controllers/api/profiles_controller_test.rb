require "test_helper"

class Api::ProfilesControllerTest < ActionDispatch::IntegrationTest
  # --- rename ---

  test "member renames themselves" do
    patch "/api/profile", params: { profile: { name: "Bobby" } }, headers: auth(users(:bob))
    assert_response :ok
    assert_equal "Bobby", response.parsed_body["name"]
    assert_equal "Bobby", users(:bob).reload.name
  end

  test "guest cannot rename" do
    patch "/api/profile", params: { profile: { name: "Bobby" } }
    assert_response :unauthorized
  end

  test "too short or too long name is refused" do
    ["", "B", "a" * 51].each do |name|
      patch "/api/profile", params: { profile: { name: name } }, headers: auth(users(:bob))
      assert_response :unprocessable_content
    end
    assert_equal "Bob", users(:bob).reload.name
  end

  test "cannot make yourself admin or change email here" do
    patch "/api/profile", params: { profile: { name: "Bob", admin: true, email: "x@x.com" } }, headers: auth(users(:bob))
    assert_not users(:bob).reload.admin?
    assert_equal "bob@example.com", users(:bob).email
  end

  test "old comments keep the old name and also send the current one" do
    patch "/api/profile", params: { profile: { name: "Bobby" } }, headers: auth(users(:bob))
    get "/api/articles/#{articles(:public_post).id}", headers: auth(users(:alice))
    c = response.parsed_body["comments"].find { |x| x["id"] == comments(:bob_on_public).id }
    assert_equal "Bob", c["commenter"]
    assert_equal "Bobby", c["current_name"]
  end

  test "anonymous comments never reveal the current name, not even to admins" do
    articles(:public_post).comments.create!(user: users(:bob), commenter: "Bob", body: "Psst", anonymous: true)
    get "/api/articles/#{articles(:public_post).id}", headers: auth(users(:admin))
    anon = response.parsed_body["comments"].find { |x| x["anonymous"] }
    assert_nil anon["commenter"]
    assert_nil anon["current_name"]
  end

  # --- change password ---

  def change_password(params, user = users(:bob))
    patch "/api/profile/password", params: params, headers: auth(user)
  end

  test "change password: new token works, old token and old password stop working" do
    change_password(password_challenge: "password123", password: "newpass456", password_confirmation: "newpass456")
    assert_response :ok
    token = response.parsed_body["token"]
    assert_not_equal "bob-token", token

    get "/api/session", headers: { "Authorization" => "Bearer bob-token" }
    assert_response :unauthorized
    get "/api/session", headers: { "Authorization" => "Bearer #{token}" }
    assert_response :ok

    assert users(:bob).reload.authenticate("newpass456")
    assert_not users(:bob).authenticate("password123")
  end

  test "wrong or missing current password is a 422 on password_challenge, not a 401" do
    [{ password_challenge: "wrong" }, {}].each do |challenge|
      change_password(challenge.merge(password: "newpass456", password_confirmation: "newpass456"))
      assert_response :unprocessable_content
      assert response.parsed_body["password_challenge"].present?
    end
    assert users(:bob).reload.authenticate("password123")
    assert_equal "bob-token", users(:bob).auth_token # still logged in everywhere
  end

  test "new password too short or not confirmed is refused" do
    change_password(password_challenge: "password123", password: "123", password_confirmation: "123")
    assert_response :unprocessable_content
    change_password(password_challenge: "password123", password: "newpass456", password_confirmation: "other456")
    assert_response :unprocessable_content
    assert users(:bob).reload.authenticate("password123")
  end

  test "empty new password is a bad request" do
    change_password(password_challenge: "password123", password: "")
    assert_response :bad_request
  end

  test "guest cannot change password" do
    patch "/api/profile/password", params: { password_challenge: "x", password: "newpass456" }
    assert_response :unauthorized
  end
end
