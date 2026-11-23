class AddAnonymousAndCommentsCount < ActiveRecord::Migration[7.1]
  def change
    # The writer chose to hide their name; user_id is still stored so they (and admins) can delete the comment
    add_column :comments, :anonymous, :boolean, default: false, null: false

    # counter_cache: lists show "3 bình luận" without counting the comments of every article
    add_column :articles, :comments_count, :integer, default: 0, null: false
    reversible do |dir|
      dir.up do
        execute "UPDATE articles SET comments_count = (SELECT COUNT(*) FROM comments WHERE comments.article_id = articles.id)"
      end
    end
  end
end
