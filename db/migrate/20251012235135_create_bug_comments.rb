class CreateBugComments < ActiveRecord::Migration[8.0]
  def change
    create_table :bug_comments do |t|
      t.integer :bug_id, null: false
      t.integer :user_id, null: false
      t.text :content, null: false
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :bug_comments, :bug_id
    add_index :bug_comments, :user_id
    add_index :bug_comments, :deleted_at
  end
end
