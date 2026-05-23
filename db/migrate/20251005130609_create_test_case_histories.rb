class CreateTestCaseHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :test_case_histories do |t|
      t.integer :test_case_id, null: false
      t.integer :user_id, null: false
      t.string :action, null: false
      t.text :old_value
      t.text :new_value

      t.timestamps
    end

    add_index :test_case_histories, :test_case_id
    add_index :test_case_histories, :user_id
    add_index :test_case_histories, :action
  end
end
