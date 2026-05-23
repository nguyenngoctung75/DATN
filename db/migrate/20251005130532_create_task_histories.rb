class CreateTaskHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :task_histories do |t|
      t.integer :task_id, null: false
      t.integer :user_id, null: false
      t.string :action, null: false
      t.text :old_value
      t.text :new_value

      t.timestamps
    end

    add_index :task_histories, :task_id
    add_index :task_histories, :user_id
    add_index :task_histories, :action
  end
end
