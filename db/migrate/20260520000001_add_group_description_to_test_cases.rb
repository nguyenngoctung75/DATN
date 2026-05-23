class AddGroupDescriptionToTestCases < ActiveRecord::Migration[8.0]
  def change
    add_column :test_cases, :group_description, :text
  end
end
