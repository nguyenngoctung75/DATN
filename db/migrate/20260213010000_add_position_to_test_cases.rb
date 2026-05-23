class AddPositionToTestCases < ActiveRecord::Migration[8.0]
  def up
    add_column :test_cases, :position, :integer
    add_index :test_cases, [:task_id, :position]

    # Gán position cho TC hiện tại dựa trên thứ tự ID
    execute <<-SQL
      UPDATE test_cases
      SET position = (
        SELECT COUNT(*)
        FROM test_cases AS tc2
        WHERE tc2.task_id = test_cases.task_id
          AND tc2.id <= test_cases.id
      )
    SQL
  end

  def down
    remove_column :test_cases, :position
  end
end
