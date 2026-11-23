class ConvertArticleBodiesToHtml < ActiveRecord::Migration[7.1]
  # Own tiny model: the real Article class may change later and must not break this old migration
  class MigrationArticle < ActiveRecord::Base
    self.table_name = "articles"
  end

  # Bodies used to be plain text; the new editor stores HTML.
  # Escape the old text ("<" stays a character, not a tag), then wrap paragraphs in <p>
  def up
    helpers = ActionController::Base.helpers
    MigrationArticle.find_each do |article|
      # update_columns: no validations and no updated_at change, so "Sửa lần cuối" stays as it was
      article.update_columns(body: helpers.simple_format(ERB::Util.html_escape(article.body.to_s)))
    end
  end

  def down
    MigrationArticle.find_each do |article|
      text = article.body.to_s.gsub(%r{</p>\s*<p>}, "\n\n").gsub(%r{<br\s*/?>\n?}, "\n")
      article.update_columns(body: CGI.unescapeHTML(ActionController::Base.helpers.strip_tags(text)))
    end
  end
end
