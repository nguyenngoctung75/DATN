class CreateTestStepContents < ActiveRecord::Migration[8.0]
  def change
    create_table :test_step_contents do |t|
      t.integer :step_id, null: false
      t.string :content_type, null: false
      t.text :content_value, null: false
      t.boolean :is_expected, default: false, null: false

      # Các trường mới cho spreadsheet import
      t.string :content_category, null: false, default: "action" # action, expectation
      t.integer :display_order, default: 0

      t.datetime :deleted_at

      t.timestamps
    end

    add_index :test_step_contents, :step_id
    add_index :test_step_contents, :content_type
    add_index :test_step_contents, :is_expected
    add_index :test_step_contents, :deleted_at
    add_index :test_step_contents, :content_category
    add_index :test_step_contents, :display_order
  end
end
