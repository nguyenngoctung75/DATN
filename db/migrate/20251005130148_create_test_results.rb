class CreateTestResults < ActiveRecord::Migration[8.0]
  def change
    create_table :test_results do |t|
      t.integer :run_id
      t.integer :case_id, null: false
      t.string :status
      t.text :device
      t.integer :executed_by_id
      t.datetime :executed_at
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :test_results, :run_id
    add_index :test_results, :case_id
    add_index :test_results, :executed_by_id
    add_index :test_results, :deleted_at
  end
end
