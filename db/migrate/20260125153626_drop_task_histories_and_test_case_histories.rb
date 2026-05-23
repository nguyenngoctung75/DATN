class DropTaskHistoriesAndTestCaseHistories < ActiveRecord::Migration[8.0]
  def change
    drop_table :task_histories, if_exists: true
    drop_table :test_case_histories, if_exists: true
  end
end
