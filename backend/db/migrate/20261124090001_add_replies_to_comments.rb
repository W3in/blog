class AddRepliesToComments < ActiveRecord::Migration[7.1]
  def change
    # parent_id: the comment this one answers (null = a top-level comment). Points to the same table
    add_reference :comments, :parent, foreign_key: { to_table: :comments }, null: true
    # A comment that has replies is not removed, only emptied ("[đã xóa]"), so the replies keep their place
    add_column :comments, :deleted_at, :datetime
  end
end
