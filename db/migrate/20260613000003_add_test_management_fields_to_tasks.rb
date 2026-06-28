# frozen_string_literal: true

class AddTestManagementFieldsToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :test_phase, :string, default: 'not_started', null: false
    add_column :tasks, :testing_type, :string
    add_column :tasks, :kpi_targets, :json

    add_index :tasks, :test_phase
    add_index :tasks, :testing_type
  end
end
