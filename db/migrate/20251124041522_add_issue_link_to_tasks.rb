class AddIssueLinkToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :issue_link, :string
  end
end
