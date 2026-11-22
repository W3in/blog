require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  test "new articles are public by default" do
    assert_equal "public", Article.new.status
  end

  test "status must be public, private or archived" do
    article = users(:alice).articles.new(title: "T", body: "Long enough body", status: "secret")
    assert_not article.valid?
    assert article.errors[:status].any?
  end

  test "body needs at least 10 characters" do
    assert_not users(:alice).articles.new(title: "T", body: "short").valid?
  end

  test "guests see only public articles" do
    assert_equal [articles(:public_post)], Article.visible_to(nil).to_a
  end

  test "members see public and private articles, not other people's archived ones" do
    assert_equal ["Private post", "Public post"], Article.visible_to(users(:bob)).pluck(:title).sort
  end

  test "authors also see their own archived articles" do
    assert_equal 3, Article.visible_to(users(:alice)).count
  end

  test "admins see everything" do
    assert_equal 3, Article.visible_to(users(:admin)).count
  end
end
