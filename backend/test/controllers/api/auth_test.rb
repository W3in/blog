require "test_helper"

# Registration (POST /api/registration) and session (POST/GET/DELETE /api/session)
class Api::AuthTest < ActionDispatch::IntegrationTest
  test "register returns a token that logs you in" do
    post "/api/registration", params: { user: { name: "Zz", email: "zz@example.com", password: "secret123", password_confirmation: "secret123" } }
    assert_response :created
    token = response.parsed_body["token"]

    get "/api/session", headers: { "Authorization" => "Bearer #{token}" }
    assert_response :ok
    assert_equal "zz@example.com", response.parsed_body["email"]
  end

  test "register with bad data returns the errors per field" do
    post "/api/registration", params: { user: { name: "", email: "alice@example.com", password: "123", password_confirmation: "456" } }
    assert_response :unprocessable_content
    assert_equal %w[email name password password_confirmation], response.parsed_body.keys.sort
  end

  test "nobody can sign up as admin" do
    post "/api/registration", params: { user: { name: "Zz", email: "zz@example.com", password: "secret123", password_confirmation: "secret123", admin: true } }
    assert_response :created
    assert_not User.find_by(email: "zz@example.com").admin?
  end

  test "register response does not leak the password hash" do
    post "/api/registration", params: { user: { name: "Zz", email: "zz@example.com", password: "secret123", password_confirmation: "secret123" } }
    assert_not_includes response.body, "password_digest"
  end

  test "login with the right password returns the user's token" do
    post "/api/session", params: { email: "ALICE@example.com", password: "password123" }
    assert_response :ok
    assert_equal "alice-token", response.parsed_body["token"]
  end

  test "wrong password and unknown email both give 401" do
    post "/api/session", params: { email: "alice@example.com", password: "wrong" }
    assert_response :unauthorized
    post "/api/session", params: { email: "nobody@example.com", password: "password123" }
    assert_response :unauthorized
  end

  test "current user includes the admin flag" do
    get "/api/session", headers: auth(users(:admin))
    assert_equal true, response.parsed_body["admin"]
  end

  test "current user needs a valid token" do
    get "/api/session"
    assert_response :unauthorized
    get "/api/session", headers: { "Authorization" => "Bearer made-up-token" }
    assert_response :unauthorized
  end

  test "logout makes the old token stop working" do
    delete "/api/session", headers: auth(users(:alice))
    assert_response :no_content

    get "/api/session", headers: { "Authorization" => "Bearer alice-token" }
    assert_response :unauthorized
  end
end
