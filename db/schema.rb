# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_06_13_000003) do
  create_table "activity_logs", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "trackable_type", null: false
    t.integer "trackable_id", null: false
    t.string "action_type"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["trackable_type", "trackable_id"], name: "index_activity_logs_on_trackable"
    t.index ["user_id"], name: "index_activity_logs_on_user_id"
  end

  create_table "app_configurations", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "ai_tc_enabled", default: false, null: false
    t.string "ai_model", default: "gemini-2.0-flash"
    t.text "ai_tc_system_prompt"
  end

  create_table "bug_comments", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "bug_id", null: false
    t.bigint "user_id", null: false
    t.text "content", null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bug_id"], name: "index_bug_comments_on_bug_id"
    t.index ["deleted_at"], name: "index_bug_comments_on_deleted_at"
    t.index ["user_id"], name: "index_bug_comments_on_user_id"
  end

  create_table "bug_evidences", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "bug_id", null: false
    t.string "content_type", null: false
    t.text "content_value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bug_id"], name: "index_bug_evidences_on_bug_id"
    t.index ["content_type"], name: "index_bug_evidences_on_content_type"
  end

  create_table "bugs", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "dev_id"
    t.bigint "tester_id"
    t.string "title", null: false
    t.text "description"
    t.string "category", null: false
    t.string "priority", null: false
    t.string "status", default: "new", null: false
    t.text "content"
    t.string "application"
    t.string "image_video_url"
    t.text "notes"
    t.string "clock"
    t.bigint "test_result_id"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "dev_name_raw"
    t.string "tester_name_raw"
    t.string "bug_type"
    t.index ["application"], name: "index_bugs_on_application"
    t.index ["category"], name: "index_bugs_on_category"
    t.index ["deleted_at"], name: "index_bugs_on_deleted_at"
    t.index ["dev_id"], name: "index_bugs_on_dev_id"
    t.index ["priority"], name: "index_bugs_on_priority"
    t.index ["status"], name: "index_bugs_on_status"
    t.index ["task_id"], name: "index_bugs_on_task_id"
    t.index ["test_result_id"], name: "index_bugs_on_test_result_id"
    t.index ["tester_id"], name: "index_bugs_on_tester_id"
  end

  create_table "ci_builds", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "task_id"
    t.string "commit_sha", limit: 40, null: false
    t.string "branch", null: false
    t.string "base_branch"
    t.string "status", null: false
    t.string "workflow_run_id", null: false
    t.string "author"
    t.string "github_url"
    t.string "pr_url"
    t.integer "pr_number"
    t.string "pr_title"
    t.string "repository"
    t.string "redmine_link"
    t.integer "redmine_issue_id"
    t.string "event_name"
    t.string "event_action"
    t.datetime "occurred_at"
    t.json "raw_payload"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["commit_sha"], name: "index_ci_builds_on_commit_sha"
    t.index ["created_at"], name: "index_ci_builds_on_created_at", order: :desc
    t.index ["redmine_issue_id"], name: "index_ci_builds_on_redmine_issue_id"
    t.index ["task_id"], name: "index_ci_builds_on_task_id"
    t.index ["workflow_run_id"], name: "index_ci_builds_on_workflow_run_id", unique: true
  end

  create_table "daily_import_runs", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "started_at"
    t.datetime "finished_at"
    t.integer "imported_count", default: 0
    t.integer "skipped_count", default: 0
    t.text "error_message"
    t.text "log_output"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "started_at"], name: "index_daily_import_runs_on_project_id_and_started_at", order: { started_at: :desc }
    t.index ["project_id"], name: "index_daily_import_runs_on_project_id"
  end

  create_table "import_runs", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "triggered_by_id"
    t.string "import_type", null: false
    t.string "status", default: "pending", null: false
    t.datetime "started_at"
    t.datetime "finished_at"
    t.integer "total_count", default: 0, null: false
    t.integer "processed_count", default: 0, null: false
    t.integer "imported_count", default: 0, null: false
    t.integer "skipped_count", default: 0, null: false
    t.text "error_message"
    t.text "log_output"
    t.text "params_json"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "started_at"], name: "index_import_runs_on_project_id_and_started_at", order: { started_at: :desc }
    t.index ["project_id"], name: "index_import_runs_on_project_id"
    t.index ["status"], name: "index_import_runs_on_status"
    t.index ["triggered_by_id"], name: "index_import_runs_on_triggered_by_id"
  end

  create_table "notification_reads", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "notification_id", null: false
    t.datetime "read_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["notification_id"], name: "index_notification_reads_on_notification_id"
    t.index ["user_id", "notification_id"], name: "index_notification_reads_on_user_id_and_notification_id", unique: true
    t.index ["user_id"], name: "index_notification_reads_on_user_id"
  end

  create_table "notifications", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "category", default: "info", null: false
    t.string "title", null: false
    t.text "message"
    t.string "link"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_notifications_on_category"
    t.index ["created_at"], name: "index_notifications_on_created_at", order: :desc
  end

  create_table "project_users", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "user_id"], name: "index_project_users_on_project_id_and_user_id", unique: true
    t.index ["project_id"], name: "index_project_users_on_project_id"
    t.index ["user_id"], name: "index_project_users_on_user_id"
  end

  create_table "projects", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "redmine_project_id"
    t.boolean "daily_import_enabled", default: false, null: false
    t.boolean "open_to_all_users", default: false, null: false
    t.string "product_version"
    t.string "development_status"
    t.json "product_info"
    t.json "test_plan"
    t.index ["deleted_at"], name: "index_projects_on_deleted_at"
  end

  create_table "solid_queue_blocked_executions", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "tasks", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "redmine_id"
    t.bigint "project_id", null: false
    t.bigint "assignee_id"
    t.integer "parent_id"
    t.integer "subtask_id"
    t.string "title", null: false
    t.text "description"
    t.string "status"
    t.decimal "estimated_time", precision: 5, scale: 2
    t.decimal "spent_time", precision: 5, scale: 2
    t.integer "percent_done"
    t.date "start_date"
    t.date "due_date"
    t.string "testcase_link"
    t.string "bug_link"
    t.string "created_by_name"
    t.string "reviewed_by_name"
    t.integer "number_of_test_cases", default: 0
    t.integer "stg_bugs_vn", default: 0
    t.integer "stg_bugs_jp", default: 0
    t.integer "prod_bugs", default: 0
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "issue_link"
    t.string "device_config"
    t.integer "subtasks_count", default: 0, null: false
    t.string "test_phase", default: "not_started", null: false
    t.string "testing_type"
    t.json "kpi_targets"
    t.index ["assignee_id"], name: "index_tasks_on_assignee_id"
    t.index ["parent_id"], name: "index_tasks_on_parent_id"
    t.index ["project_id", "created_at"], name: "index_tasks_on_project_id_and_created_at"
    t.index ["project_id", "deleted_at"], name: "index_tasks_on_project_id_and_deleted_at"
    t.index ["project_id"], name: "index_tasks_on_project_id"
    t.index ["status"], name: "index_tasks_on_status"
    t.index ["test_phase"], name: "index_tasks_on_test_phase"
    t.index ["testing_type"], name: "index_tasks_on_testing_type"
  end

  create_table "test_cases", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "created_by_id"
    t.text "title", null: false
    t.text "description"
    t.string "test_type"
    t.string "target"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "note"
    t.integer "position"
    t.text "group_description"
    t.boolean "generated_by_ai", default: false, null: false
    t.index ["created_by_id"], name: "index_test_cases_on_created_by_id"
    t.index ["deleted_at"], name: "index_test_cases_on_deleted_at"
    t.index ["target"], name: "index_test_cases_on_target"
    t.index ["task_id", "position"], name: "index_test_cases_on_task_id_and_position"
    t.index ["task_id"], name: "index_test_cases_on_task_id"
    t.index ["test_type"], name: "index_test_cases_on_test_type"
  end

  create_table "test_results", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "run_id"
    t.bigint "case_id", null: false
    t.string "status"
    t.text "device"
    t.bigint "executed_by_id"
    t.datetime "executed_at"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["case_id"], name: "index_test_results_on_case_id"
    t.index ["deleted_at"], name: "index_test_results_on_deleted_at"
    t.index ["executed_by_id"], name: "index_test_results_on_executed_by_id"
    t.index ["run_id"], name: "index_test_results_on_run_id"
  end

  create_table "test_runs", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.integer "executed_by_id"
    t.string "name", null: false
    t.text "description"
    t.datetime "executed_at"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status", default: "pending", null: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.index ["deleted_at"], name: "index_test_runs_on_deleted_at"
    t.index ["executed_at"], name: "index_test_runs_on_executed_at"
    t.index ["executed_by_id"], name: "index_test_runs_on_executed_by_id"
    t.index ["status"], name: "index_test_runs_on_status"
    t.index ["task_id"], name: "index_test_runs_on_task_id"
  end

  create_table "test_step_contents", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "step_id", null: false
    t.string "content_type", null: false
    t.text "content_value", null: false
    t.boolean "is_expected", default: false, null: false
    t.string "content_category", default: "action", null: false
    t.integer "display_order", default: 0
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_category"], name: "index_test_step_contents_on_content_category"
    t.index ["content_type"], name: "index_test_step_contents_on_content_type"
    t.index ["deleted_at"], name: "index_test_step_contents_on_deleted_at"
    t.index ["display_order"], name: "index_test_step_contents_on_display_order"
    t.index ["is_expected"], name: "index_test_step_contents_on_is_expected"
    t.index ["step_id"], name: "index_test_step_contents_on_step_id"
  end

  create_table "test_steps", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "case_id", null: false
    t.integer "step_number", null: false
    t.text "description"
    t.integer "display_order", default: 0
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["case_id"], name: "index_test_steps_on_case_id"
    t.index ["deleted_at"], name: "index_test_steps_on_deleted_at"
    t.index ["display_order"], name: "index_test_steps_on_display_order"
    t.index ["step_number"], name: "index_test_steps_on_step_number"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "email", null: false
    t.string "provider", default: "local", null: false
    t.string "name"
    t.string "avatar"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "role", default: 1, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "activity_logs", "users"
  add_foreign_key "bug_comments", "bugs"
  add_foreign_key "bug_comments", "users"
  add_foreign_key "bug_evidences", "bugs"
  add_foreign_key "bugs", "tasks"
  add_foreign_key "bugs", "test_results"
  add_foreign_key "bugs", "users", column: "dev_id"
  add_foreign_key "bugs", "users", column: "tester_id"
  add_foreign_key "ci_builds", "tasks"
  add_foreign_key "daily_import_runs", "projects"
  add_foreign_key "import_runs", "projects"
  add_foreign_key "import_runs", "users", column: "triggered_by_id"
  add_foreign_key "notification_reads", "notifications"
  add_foreign_key "notification_reads", "users"
  add_foreign_key "project_users", "projects"
  add_foreign_key "project_users", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "tasks", "projects"
  add_foreign_key "tasks", "users", column: "assignee_id"
  add_foreign_key "test_cases", "tasks"
  add_foreign_key "test_cases", "users", column: "created_by_id"
  add_foreign_key "test_results", "test_cases", column: "case_id"
  add_foreign_key "test_results", "test_runs", column: "run_id"
  add_foreign_key "test_results", "users", column: "executed_by_id"
  add_foreign_key "test_runs", "tasks"
  add_foreign_key "test_step_contents", "test_steps", column: "step_id"
  add_foreign_key "test_steps", "test_cases", column: "case_id"
end
