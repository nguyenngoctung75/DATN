# frozen_string_literal: true

class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # projects: archived list uses Project.deleted.order(deleted_at: :desc)
    add_index :projects, :deleted_at, if_not_exists: true

    # tasks: project.tasks.active and Task.active filter by project_id + deleted_at
    add_index :tasks, [ :project_id, :deleted_at ], name: 'index_tasks_on_project_id_and_deleted_at', if_not_exists: true

    # tasks: project show orders by created_at and filters by date range
    add_index :tasks, [ :project_id, :created_at ], name: 'index_tasks_on_project_id_and_created_at', if_not_exists: true
  end
end
