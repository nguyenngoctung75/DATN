class AddNoteToTestCases < ActiveRecord::Migration[8.0]
  def change
    add_column :test_cases, :note, :text
  end
end
