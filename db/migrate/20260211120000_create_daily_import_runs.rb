# frozen_string_literal: true

class CreateDailyImportRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :daily_import_runs do |t|
      t.references :project, null: false, foreign_key: true
      t.string :status, null: false, default: "pending" # pending, running, success, failed
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :imported_count, default: 0
      t.integer :skipped_count, default: 0
      t.text :error_message
      t.text :log_output
      t.timestamps
    end
    add_index :daily_import_runs, [ :project_id, :started_at ], order: { started_at: :desc }
  end
end
