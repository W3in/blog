class CreateLikes < ActiveRecord::Migration[7.1]
  def change
    # One heart = one row. likeable is polymorphic: likeable_type "Article" or "Comment" + likeable_id
    create_table :likes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :likeable, polymorphic: true, null: false
      t.timestamps
    end
    # The database itself refuses a second heart from the same person on the same thing
    add_index :likes, [:user_id, :likeable_type, :likeable_id], unique: true

    # counter_cache columns: the count is stored, not counted on every page load
    add_column :articles, :likes_count, :integer, default: 0, null: false
    add_column :comments, :likes_count, :integer, default: 0, null: false
  end
end
