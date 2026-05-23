class DropProjectHistories < ActiveRecord::Migration[8.0]
  def change
    drop_table :project_histories, if_exists: true do |t|
      t.integer :project_id, null: false
      t.integer :user_id, null: false
      t.string :action, null: false
      t.text :old_value
      t.text :new_value
      t.timestamps
    end
  end
end
