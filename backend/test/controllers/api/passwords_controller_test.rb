require "test_helper"

# Forgot password: POST /api/password sends a link, PATCH /api/password sets the new password
class Api::PasswordsControllerTest < ActionDispatch::IntegrationTest
  def reset_token(user = users(:alice))
    user.generate_token_for(:password_reset)
  end

  def reset(token, password = "newpass123", confirmation = password)
    patch "/api/password", params: { token: token, password: password, password_confirmation: confirmation }
  end

  test "known email gets one email with a link to the Nuxt reset page" do
    assert_emails(1) { post "/api/password", params: { email: "ALICE@example.com" } }
    assert_response :accepted
    mail = ActionMailer::Base.deliveries.last
    assert_equal ["alice@example.com"], mail.to
    assert_includes mail.body.to_s, "http://localhost:8000/reset-password?token="
  end

  test "unknown email gets the same answer but no email" do
    assert_no_emails { post "/api/password", params: { email: "nobody@example.com" } }
    assert_response :accepted
  end

  test "valid token sets the new password" do
    reset(reset_token)
    assert_response :no_content

    post "/api/session", params: { email: "alice@example.com", password: "newpass123" }
    assert_response :ok
  end

  test "resetting logs out the old token" do
    reset(reset_token)
    get "/api/session", headers: { "Authorization" => "Bearer alice-token" }
    assert_response :unauthorized
  end

  test "a link works only once" do
    token = reset_token
    reset(token)
    reset(token, "another123")
    assert_response :unprocessable_content
  end

  test "link expires after 15 minutes" do
    token = reset_token
    travel 16.minutes do
      reset(token)
    end
    assert_response :unprocessable_content
  end

  test "made-up token is rejected" do
    reset("made-up")
    assert_response :unprocessable_content
    assert response.parsed_body["token"].any?
  end

  test "new password still has to be valid" do
    reset(reset_token, "12345")
    assert_response :unprocessable_content
    reset(reset_token, "newpass123", "different")
    assert_response :unprocessable_content
  end

  test "empty password is refused" do
    reset(reset_token, "")
    assert_response :bad_request
  end
end
