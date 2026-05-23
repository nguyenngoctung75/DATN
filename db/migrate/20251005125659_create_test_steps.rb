class CreateTestSteps < ActiveRecord::Migration[8.0]
  def change
    create_table :test_steps do |t|
      t.integer :case_id, null: false
      t.integer :step_number, null: false
      t.text :description

      # Các trường mới cho spreadsheet import
      t.string :function
      t.integer :display_order, default: 0

      t.datetime :deleted_at

      t.timestamps
    end

    add_index :test_steps, :case_id
    add_index :test_steps, :step_number
    add_index :test_steps, :deleted_at
    add_index :test_steps, :display_order
  end
end
