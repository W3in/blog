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

  test "tags alone do not count as text" do
    assert_not users(:alice).articles.new(title: "T", body: "<p></p><p><img src=\"/a.png\"></p>").valid?
  end

  test "dangerous HTML is removed before saving, safe formatting stays" do
    article = users(:alice).articles.create!(title: "T", body: <<~HTML)
      <p onclick="steal()">Hello <strong>world</strong> and more text</p>
      <script>alert(1)</script>
      <a href="javascript:alert(1)">bad link</a>
      <img src="/api/files/a.png" onerror="alert(1)">
    HTML
    assert_includes article.body, "<strong>world</strong>"
    assert_includes article.body, '<img src="/api/files/a.png">'
    assert_not_includes article.body, "onclick"
    assert_not_includes article.body, "<script"
    assert_not_includes article.body, "javascript:"
    assert_not_includes article.body, "onerror"
  end

  test "style keeps only color, highlight, font and alignment" do
    article = users(:alice).articles.create!(title: "T", body: <<~HTML)
      <p style="text-align: center; position: fixed">Centered <span style="color: #e8590c; background-color: #fff3bf; font-family: 'Playfair Display', serif; float: left; background: url(x.png)">styled</span> text</p>
      <img src="/api/files/a.png" width="480" height="270" style="width: 9999px">
    HTML
    assert_includes article.body, "text-align:center"
    assert_includes article.body, "color:#e8590c"
    assert_includes article.body, "background-color:#fff3bf"
    assert_includes article.body, "Playfair Display"
    assert_includes article.body, 'width="480"'
    assert_not_includes article.body, "position"
    assert_not_includes article.body, "float"
    assert_not_includes article.body, "url("
    assert_not_includes article.body, "9999px"
  end

  test "title is at most 300 characters" do
    assert users(:alice).articles.new(title: "a" * 300, body: "Long enough body").valid?
    assert_not users(:alice).articles.new(title: "a" * 301, body: "Long enough body").valid?
  end

  test "preview keeps whole blocks with their formatting and shortens the block over the limit" do
    article = Article.new(body: "<p><strong>Intro</strong></p><p>#{"x" * 500}</p><p>Never shown</p>")
    assert article.preview.start_with?("<p><strong>Intro</strong></p><p>xxx")
    assert article.preview.end_with?("…</p>")
    assert_not_includes article.preview, "Never shown"
    assert article.preview_truncated?
  end

  test "excerpt is plain text with spaces between paragraphs and list items" do
    assert_equal "One & two Three", Article.new(body: "<p>One &amp; two</p><p>Three</p>").excerpt
    assert_equal "Day 1: lake Day 2: hill", Article.new(body: "<ul><li><strong>Day 1:</strong> lake</li><li>Day 2: hill</li></ul>").excerpt
    assert_equal "Go check-in, then rest", Article.new(body: "<p>Go <strong>check-in</strong>, then rest</p>").excerpt
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

  test "image alignment keeps only left, center and right" do
    article = users(:alice).articles.create!(title: "T", body: '<p>Some text here</p><img src="/api/files/a.png" data-align="right"><img src="/api/files/b.png" data-align="evil">')
    assert_includes article.body, 'data-align="right"'
    assert_not_includes article.body, "evil"
  end

  test "slug is the title without accents, then the id at the end (like VnExpress)" do
    assert_equal "da-lat-mua-mua-an-gi-6", Article.new(id: 6, title: "Đà Lạt mùa mưa: Ăn gì?").slug
    assert_equal "5-thu-doan-trong-nam-2026-9", Article.new(id: 9, title: "5 thủ đoạn trong năm 2026").slug
    assert_equal "7", Article.new(id: 7, title: "😀😀").slug # nothing readable: just the id
  end

end
