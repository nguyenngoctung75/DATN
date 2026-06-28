class AddGeneratedByAiToTestCases < ActiveRecord::Migration[8.0]
  def change
    add_column :test_cases, :generated_by_ai, :boolean, default: false, null: false
  end
end
