# frozen_string_literal: true

module Scripts
  # Placeholder constant so Zeitwerk can eager load this file safely.
  # The legacy runner script content is intentionally kept commented below.
  class ResetData
  end
end

# Usage: bin/rails runner lib/scripts/reset_data.rb
#
# Deletes ALL data except users and projects.
# Resets auto-increment IDs back to 1 for cleared tables.

# KEEP_TABLES = %w[users projects schema_migrations ar_internal_metadata app_configurations].freeze

# # All tables to clear (order matters: delete children before parents)
# TABLES_TO_CLEAR = %w[
#   activity_logs
#   bug_comments
#   bug_evidences
#   bugs
#   daily_import_runs
#   notification_reads
#   notifications
#   test_results
#   test_step_contents
#   test_steps
#   test_cases
#   test_runs
#   tasks
# ].freeze

# puts '=' * 60
# puts '  RESET DATA (keep users & projects)'
# puts '=' * 60

# ActiveRecord::Base.transaction do
#   TABLES_TO_CLEAR.each do |table|
#     count = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM #{table}").first[0]
#     ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
#     ActiveRecord::Base.connection.execute("DELETE FROM sqlite_sequence WHERE name='#{table}'")
#     puts "  [OK] #{table}: deleted #{count} rows, ID reset to 1"
#   end
# end

# puts '-' * 60
# puts '  Kept tables: users, projects, app_configurations'
# puts "  Users: #{User.count} | Projects: #{Project.count}"
# puts '=' * 60
# puts '  DONE!'
