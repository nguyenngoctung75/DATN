# frozen_string_literal: true

class CreateCiBuilds < ActiveRecord::Migration[8.0]
  def change
    create_table :ci_builds do |t|
      t.references :task, foreign_key: true, null: true
      t.string   :commit_sha,        null: false, limit: 40
      t.string   :branch,            null: false
      t.string   :base_branch
      t.string   :status,            null: false # success | failed
      t.string   :workflow_run_id,   null: false
      t.string   :author
      t.string   :github_url
      t.string   :pr_url
      t.integer  :pr_number
      t.string   :pr_title
      t.string   :repository
      t.string   :redmine_link
      t.integer  :redmine_issue_id
      t.string   :event_name
      t.string   :event_action
      t.datetime :occurred_at
      t.json     :raw_payload
      t.timestamps
    end

    add_index :ci_builds, :commit_sha
    add_index :ci_builds, :workflow_run_id, unique: true
    add_index :ci_builds, :redmine_issue_id
    add_index :ci_builds, :created_at, order: { created_at: :desc }
  end
end
