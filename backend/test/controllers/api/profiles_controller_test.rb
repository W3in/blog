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

  test "wrong current password message is in Vietnamese" do
    change_password(password_challenge: "wrong", password: "newpass456", password_confirmation: "newpass456")
    assert_equal ["không đúng"], response.parsed_body["password_challenge"]
  end

  # --- change email ---

  test "change email with the right password" do
    patch "/api/profile/email", params: { password_challenge: "password123", email: " Bobby@Example.com " }, headers: auth(users(:bob))
    assert_response :ok
    assert_equal "bobby@example.com", response.parsed_body["email"] # normalizes: trimmed, lower case
    assert_equal "bobby@example.com", users(:bob).reload.email
  end

  test "change email: wrong or missing password, taken or invalid email are refused" do
    [
      { password_challenge: "wrong", email: "new@example.com" },
      { email: "new@example.com" },
      { password_challenge: "password123", email: "alice@example.com" },
      { password_challenge: "password123", email: "not-an-email" }
    ].each do |params|
      patch "/api/profile/email", params: params, headers: auth(users(:bob))
      assert_response :unprocessable_content
    end
    assert_equal "bob@example.com", users(:bob).reload.email
  end

  test "a reset link stops working once the email changes" do
    token = users(:bob).generate_token_for(:password_reset)
    patch "/api/profile/email", params: { password_challenge: "password123", email: "bobby@example.com" }, headers: auth(users(:bob))
    assert_nil User.find_by_token_for(:password_reset, token)
  end

  # --- avatar ---

  def upload_avatar(name, user = users(:bob))
    put "/api/profile/avatar", params: { file: fixture_file_upload(name, "image/png", true) }, headers: auth(user)
  end

  test "upload an avatar: it shows in the session, next to articles and comments, and serves the image" do
    upload_avatar("pixel.png")
    assert_response :ok
    url = response.parsed_body["avatar_url"]
    assert url.start_with?("/api/files/blobs/proxy/")

    get "/api/session", headers: auth(users(:bob))
    assert_equal url, response.parsed_body["avatar_url"]

    get "/api/articles/#{articles(:public_post).id}", headers: auth(users(:alice))
    bob_comment = response.parsed_body["comments"].find { |c| c["id"] == comments(:bob_on_public).id }
    assert_equal url, bob_comment["avatar_url"]

    get url
    assert_equal file_fixture("pixel.png").binread, response.body
  end

  test "a new avatar replaces the old one" do
    upload_avatar("pixel.png")
    assert_no_difference("ActiveStorage::Attachment.count") { upload_avatar("pixel.png") }
  end

  test "anonymous comments never show the avatar" do
    upload_avatar("pixel.png")
    articles(:public_post).comments.create!(user: users(:bob), commenter: "Bob", body: "Psst", anonymous: true)
    get "/api/articles/#{articles(:public_post).id}", headers: auth(users(:admin))
    assert_nil response.parsed_body["comments"].find { |c| c["anonymous"] }["avatar_url"]
  end

  test "a text file named .png is not accepted as avatar" do
    upload_avatar("fake.png")
    assert_response :unprocessable_content
    assert_not users(:bob).reload.avatar.attached?
  end

  test "remove the avatar" do
    upload_avatar("pixel.png")
    delete "/api/profile/avatar", headers: auth(users(:bob))
    assert_response :ok
    assert_nil response.parsed_body["avatar_url"]
    assert_not users(:bob).reload.avatar.attached?
  end

  test "guest cannot set an avatar" do
    put "/api/profile/avatar", params: { file: fixture_file_upload("pixel.png", "image/png", true) }
    assert_response :unauthorized
  end

  # --- delete account ---

  test "delete account needs the right password" do
    delete "/api/profile", params: { password_challenge: "wrong" }, headers: auth(users(:alice))
    assert_response :unprocessable_content
    assert_equal ["không đúng"], response.parsed_body["password_challenge"]
    assert User.exists?(users(:alice).id)
  end

  test "delete account Reddit-style: articles and comments stay as [đã xóa], login and personal data go" do
    alice = users(:alice)
    put "/api/profile/avatar", params: { file: fixture_file_upload("pixel.png", "image/png", true) }, headers: auth(alice)

    assert_no_difference -> { Article.count }, -> { Comment.count } do
      delete "/api/profile", params: { password_challenge: "password123" }, headers: auth(alice)
    end
    assert_response :no_content

    alice.reload
    assert alice.deleted
    assert_equal "[đã xóa]", alice.name
    assert_not_equal "alice@example.com", alice.email
    assert_not alice.avatar.attached?

    # the old token and the old password no longer log in
    get "/api/session", headers: { "Authorization" => "Bearer alice-token" }
    assert_response :unauthorized
    post "/api/session", params: { email: "alice@example.com", password: "password123" }
    assert_response :unauthorized

    # the article is still there, its author and her comments show as deleted, nothing personal leaks
    get "/api/articles/#{articles(:public_post).id}", headers: auth(users(:bob))
    body = response.parsed_body
    assert_equal({ "id" => alice.id, "name" => "[đã xóa]", "avatar_url" => nil, "deleted" => true }, body["user"])
    alice_comment = body["comments"].find { |c| c["id"] == comments(:alice_on_public).id }
    assert_equal "[đã xóa]", alice_comment["commenter"]
    assert_equal "[đã xóa]", alice_comment["current_name"] # same as commenter: no "renamed" tooltip
    assert_not_includes response.body, "Alice"

    # no public page, and the email is free for a new account
    get "/api/users/#{alice.id}"
    assert_response :not_found
    post "/api/registration", params: { user: { name: "Alice 2", email: "alice@example.com", password: "secret123", password_confirmation: "secret123" } }
    assert_response :created
  end
end
