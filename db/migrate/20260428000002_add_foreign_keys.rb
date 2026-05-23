class AddForeignKeys < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :tasks, :projects
    add_foreign_key :tasks, :users, column: :assignee_id

    add_foreign_key :test_cases, :tasks
    add_foreign_key :test_cases, :users, column: :created_by_id

    add_foreign_key :test_runs, :tasks

    add_foreign_key :test_results, :test_cases, column: :case_id
    add_foreign_key :test_results, :test_runs, column: :run_id
    add_foreign_key :test_results, :users, column: :executed_by_id

    add_foreign_key :test_steps, :test_cases, column: :case_id
    add_foreign_key :test_step_contents, :test_steps, column: :step_id

    add_foreign_key :bugs, :tasks
    add_foreign_key :bugs, :users, column: :dev_id
    add_foreign_key :bugs, :users, column: :tester_id
    add_foreign_key :bugs, :test_results

    add_foreign_key :bug_comments, :bugs
    add_foreign_key :bug_comments, :users

    add_foreign_key :bug_evidences, :bugs
  end
end
