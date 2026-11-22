class CleanUpStatusColumns < ActiveRecord::Migration[7.1]
  def change
    # Articles without a status were hidden from everyone but admin: make them public, and new ones public by default
    change_column_default :articles, :status, from: nil, to: "public"
    change_column_null :articles, :status, false, "public"

    # Comments follow their article's visibility, so their own status (left over from the Rails guide) meant nothing
    remove_column :comments, :status, :string
  end
end
