class AddBugTypeToBugs < ActiveRecord::Migration[8.0]
  def change
    add_column :bugs, :bug_type, :string
  end
end
