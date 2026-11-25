class AddCreatedAtIndexToArticles < ActiveRecord::Migration[7.1]
  def change
    add_index :articles, [:created_at, :id]
  end
end