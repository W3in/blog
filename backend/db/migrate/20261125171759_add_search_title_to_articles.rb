class AddSearchTitleToArticles < ActiveRecord::Migration[7.1]
  def up
    add_column :articles, :search_title, :string
    # Fill it for the articles that already exist; new and edited ones get it from Article's before_save
    Article.reset_column_information
    Article.find_each { |article| article.update_column(:search_title, Article.unaccent(article.title)) }
  end

  def down
    remove_column :articles, :search_title
  end
end