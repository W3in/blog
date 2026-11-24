class CreateNotifications < ActiveRecord::Migration[7.1]
  def change
    create_table :notifications do |t|
      t.references :recipient, null: false, foreign_key: { to_table: :users } # who gets it
      t.references :actor, null: false, foreign_key: { to_table: :users }     # who did it
      t.string :kind, null: false                                             # "comment" or "reply"
      t.references :comment, null: false, foreign_key: true                   # the new comment (has the article)
      t.datetime :read_at                                                     # null = unread
      t.timestamps
    end
    add_index :notifications, [:recipient_id, :read_at]
  end
end
