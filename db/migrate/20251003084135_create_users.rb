class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email, null: false, index: { unique: true }
      t.string :password_digest # để dùng has_secure_password
      t.string :provider, null: false, default: "local" # local | google
      t.string :name
      t.string :avatar
      t.string :role, null: false, default: "tester" # admin | tester | developer
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
