class UpdateUsersForDeviseAndRole < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :encrypted_password, :string, null: false, default: ""
    add_column :users, :reset_password_token, :string
    add_column :users, :reset_password_sent_at, :datetime
    add_column :users, :remember_created_at, :datetime

    add_index :users, :reset_password_token, unique: true

    remove_column :users, :password_digest, :string

    # Change role from string to integer: 0 = admin, 1 = user, 2 = developer
    remove_column :users, :role, :string
    add_column :users, :role, :integer, default: 1, null: false
  end
end
