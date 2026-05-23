class CreateTestRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :test_runs do |t|
      t.integer :task_id, null: false
      t.integer :executed_by_id
      t.string :name, null: false
      t.text :description
      t.datetime :executed_at
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :test_runs, :task_id
    add_index :test_runs, :executed_by_id
    add_index :test_runs, :executed_at
    add_index :test_runs, :deleted_at
  end
end
