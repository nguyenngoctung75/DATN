class CreateImportRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :import_runs do |t|
      t.references :project, null: false, foreign_key: true
      t.references :triggered_by, foreign_key: { to_table: :users }
      t.string :import_type, null: false
      t.string :status, default: 'pending', null: false
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :total_count, default: 0, null: false
      t.integer :processed_count, default: 0, null: false
      t.integer :imported_count, default: 0, null: false
      t.integer :skipped_count, default: 0, null: false
      t.text :error_message
      t.text :log_output
      t.text :params_json

      t.timestamps
    end

    add_index :import_runs, [ :project_id, :started_at ], order: { started_at: :desc },
              name: 'index_import_runs_on_project_id_and_started_at'
    add_index :import_runs, :status
  end
end
