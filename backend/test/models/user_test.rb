require "test_helper"

class UserTest < ActiveSupport::TestCase
  def build(attrs = {})
    User.new({ name: "Zz", email: "zz@example.com", password: "secret123" }.merge(attrs))
  end

  test "valid with name, email and password" do
    assert build.valid?
  end

  test "email is stored trimmed and lowercase" do
    assert_equal "zz@example.com", build(email: "  ZZ@Example.COM ").email
  end

  test "email must look like an email" do
    assert_not build(email: "not-an-email").valid?
  end

  test "email must be unique, ignoring case" do
    assert_not build(email: "ALICE@example.com").valid?
  end

  test "name is required" do
    assert_not build(name: "").valid?
  end

  test "password needs at least 6 characters" do
    assert_not build(password: "12345").valid?
  end

  test "gets an auth token on create" do
    user = build
    user.save!
    assert_not_nil user.auth_token
  end
end
