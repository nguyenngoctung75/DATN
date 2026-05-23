class AddRawNamesToBugs < ActiveRecord::Migration[8.0]
  def change
    add_column :bugs, :dev_name_raw, :string
    add_column :bugs, :tester_name_raw, :string
  end
end
