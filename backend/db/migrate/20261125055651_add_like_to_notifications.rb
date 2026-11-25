class AddLikeToNotifications < ActiveRecord::Migration[7.1]
  def change
    change_column_null :notifications, :comment_id, true

    add_reference :notifications, :like, foreign_key: { on_delete: :cascade }
  end
end
