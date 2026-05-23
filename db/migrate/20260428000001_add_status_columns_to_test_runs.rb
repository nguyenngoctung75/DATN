class AddStatusColumnsToTestRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :test_runs, :status, :string, default: 'pending', null: false
    add_column :test_runs, :started_at, :datetime
    add_column :test_runs, :completed_at, :datetime

    add_index :test_runs, :status
  end
end
