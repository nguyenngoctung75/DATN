class DropUnusedColumnsFromTestCasesAndTestSteps < ActiveRecord::Migration[8.0]
  def change
    remove_column :test_cases, :function,                :string
    remove_column :test_cases, :expected_result,         :text
    remove_column :test_cases, :acceptance_criteria_url, :string
    remove_column :test_cases, :user_story_url,          :string

    remove_column :test_steps, :function, :string
  end
end
