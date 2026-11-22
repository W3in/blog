require "test_helper"

class CommentTest < ActiveSupport::TestCase
  test "body is required" do
    assert_not articles(:public_post).comments.new(user: users(:bob), body: "  ").valid?
  end

  test "needs a user" do
    assert_not articles(:public_post).comments.new(body: "Hi").valid?
  end
end
