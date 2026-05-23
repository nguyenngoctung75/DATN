class AddSubtasksCountToTasks < ActiveRecord::Migration[8.0]
  def up
    add_column :tasks, :subtasks_count, :integer, default: 0, null: false
    execute <<~SQL
      UPDATE tasks SET subtasks_count = (
        SELECT COUNT(*) FROM tasks t2 WHERE t2.parent_id = tasks.id
      )
    SQL
  end

  def down
    remove_column :tasks, :subtasks_count
  end
end
