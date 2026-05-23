# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
require_relative "../config/environment" unless defined?(Rails)

puts "=== Resetting Database Data ==="
# Model order matters for delete_all due to foreign keys if they are enforced (sqlite usually isn't unless PRAGMA is on)
# We use delete_all for speed as we are clearing everything.
models = [
  BugComment, BugEvidence, NotificationRead, ActivityLog,
  DailyImportRun, TestResult, TestRun, Bug, TestStepContent,
  TestStep, TestCase, Task, Project, Notification, User
]

models.each do |model|
  puts "Deleting #{model.name} records..."
  model.delete_all
end

tables = %w[
  bug_comments bug_evidences notification_reads activity_logs
  daily_import_runs test_results test_runs bugs test_step_contents
  test_steps test_cases tasks projects notifications users
]

tables.each do |table_name|
  ActiveRecord::Base.connection.execute("ALTER TABLE #{table_name} AUTO_INCREMENT = 1")
end
puts "Database tables cleared and ID sequences reset."

puts "\n=== Creating Default Projects ==="
project_names = ["Project Alpha", "Project Beta", "Project Gamma", "Project Delta"]
project_names.each do |name|
  Project.create!(name: name)
  puts "Created project: #{name}"
end

puts "\n=== Seeding Users ==="
default_password = "123456"

# 1. Admin User
admin_email = "admin@example.com"
admin = User.create!(
  name: "admin",
  email: admin_email,
  password: default_password,
  password_confirmation: default_password,
  role: :admin,
  provider: "local"
)
puts "Admin seeded: #{admin_email}"

# 2. Regular Users
users_list = (1..17).map do |i|
  { name: "User #{i}", email: "user#{i}@example.com" }
end

users_list.each do |u|
  User.create!(
    name: u[:name],
    email: u[:email],
    password: default_password,
    password_confirmation: default_password,
    role: :user,
    provider: "local"
  )
  puts "User seeded: #{u[:email]} (#{u[:name]})"
end

puts "\n=== Seed completed ==="
puts "Total Projects: #{Project.count}"
puts "Total Users: #{User.count}"
