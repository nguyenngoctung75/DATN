class ChangeTestCasesTitleToText < ActiveRecord::Migration[8.0]
  def change
    change_column :test_cases, :title, :text, null: false
  end
end
