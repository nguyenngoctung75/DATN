# frozen_string_literal: true

# Seed dữ liệu giả lập cho hệ thống Test Case Management Tool.
#
#   Project #1 (web id=1) = "Tooltest" (redmine=seed-tooltest) — dữ liệu ĐẦY ĐỦ
#               (test step / content / test run / test result / bug + comment + evidence).
#   Project #2,#3 = 2 project fake từ Redmine (banking, ecommerce) — dữ liệu NHẸ
#               (test case + bug tối thiểu).
#
# Cả 3 project: redmine_id = id của issue "4. Testing" (đọc tmp/redmine_seed_output.json),
# mỗi project 200 task gốc (190 closed / 10 open) theo layout cố định trong Seeds::ProjectBuilder.
#
# Tất định giữa các máy (chỉ created_at khác do Time.current): web id luôn 1..N nhờ TRUNCATE +
# reset AUTO_INCREMENT; redmine_id tất định nếu Redmine được seed từ trạng thái sạch (máy mới).
#
# Phụ thuộc: chạy script/seed_redmine_bootstrap.rb + script/seed_redmine.rb TRƯỚC để có JSON.
#
#   docker exec tool_test_project-web-1 bash -c "cd /rails && bin/rails db:seed"

require_relative '../config/environment' unless defined?(Rails)
require_relative 'seeds/project_builder'

# Thứ tự tạo project web (Tooltest đầu tiên ⇒ web id = 1). mode :full / :light.
PROJECT_CONFIGS = [
  { identifier: 'seed-tooltest',       mode: :full  },
  { identifier: 'seed-mobile-banking', mode: :light },
  { identifier: 'seed-ecommerce-shop', mode: :light }
].freeze

# ---------------------------------------------------------------------------
# 1. Reset toàn bộ dữ liệu nghiệp vụ + AUTO_INCREMENT về 1
# ---------------------------------------------------------------------------
RESET_TABLES = %w[
  activity_logs app_configurations bug_comments bug_evidences bugs ci_builds
  daily_import_runs import_runs notification_reads notifications
  test_step_contents test_steps test_results test_runs test_cases
  tasks projects users
].freeze

puts '=== Reset dữ liệu (TRUNCATE + AUTO_INCREMENT=1) ==='
conn = ActiveRecord::Base.connection
conn.execute('SET FOREIGN_KEY_CHECKS = 0')
RESET_TABLES.each do |table|
  next unless conn.table_exists?(table)

  conn.execute("TRUNCATE TABLE #{table}")
end
conn.execute('SET FOREIGN_KEY_CHECKS = 1')
puts "Đã xoá #{RESET_TABLES.size} bảng, reset STT về 1."

# ---------------------------------------------------------------------------
# 2. Users (1 admin + 17 user) — email phải thuộc @example.com (User validation)
# ---------------------------------------------------------------------------
puts "\n=== Tạo Users ==="
PASSWORD = '123456'
admin = User.create!(name: 'admin', email: 'admin@example.com',
                     password: PASSWORD, password_confirmation: PASSWORD,
                     role: :admin, provider: 'local')
users = [ admin ] + (1..17).map do |i|
  User.create!(name: "User #{i}", email: "user#{i}@example.com",
               password: PASSWORD, password_confirmation: PASSWORD,
               role: :user, provider: 'local')
end
puts "Đã tạo #{users.size} user (1 admin + 17 user)."

# ---------------------------------------------------------------------------
# 3. Cửa sổ thời gian — mọi task open created_at > mọi task closed created_at
# ---------------------------------------------------------------------------
now = Time.current
TIME_WINDOW = {
  closed_from: now - 120.days, closed_to: now - 30.days,
  open_from: now - 20.days, open_to: now - 1.day
}.freeze

def summarize(label, stats)
  parts = stats.map { |k, v| "#{k}=#{v}" }.join(', ')
  puts "  [#{label}] #{parts}"
end

# ---------------------------------------------------------------------------
# 4. Tạo 3 project từ JSON Redmine (redmine_id thật). Tooltest đầu tiên ⇒ web id=1.
# ---------------------------------------------------------------------------
# Thiếu JSON Redmine (vd môi trường CI/e2e, hoặc lần boot đầu chạy `db:prepare`) ⇒
# KHÔNG abort: chỉ tạo users ở trên rồi kết thúc êm (để không làm gãy db:prepare/boot).
# Seed đầy đủ 3 project cần chạy bootstrap + script/seed_redmine.rb trước (xem docs/SEED_DATA.md).
json_path = Rails.root.join('tmp/redmine_seed_output.json')

if File.exist?(json_path)
  data = JSON.parse(File.read(json_path))
  by_identifier = data['projects'].index_by { |p| p['identifier'] }

  PROJECT_CONFIGS.each_with_index do |cfg, idx|
    proj = by_identifier[cfg[:identifier]]
    abort "Không thấy project '#{cfg[:identifier]}' trong JSON Redmine." unless proj

    issues = proj['issues']
    if issues.size != 200
      abort "Project '#{cfg[:identifier]}' cần 200 issue (có #{issues.size}). " \
            'Chạy lại script/seed_redmine.rb (target 200).'
    end

    root_specs = issues.map do |iss|
      { title: iss['subject'], redmine_id: iss['id'], status: iss['status'].to_s }
    end

    puts "\n=== Project ##{idx + 1}: #{proj['name']} (#{cfg[:mode]}, redmine=#{cfg[:identifier]}) ==="
    ActiveRecord::Base.transaction do
      profile = Seeds::ContentLibrary::PROJECT_PROFILES[cfg[:identifier]] || {}
      project = Project.create!(
        name: proj['name'],
        description: proj['description'].presence || "Project kiểm thử đồng bộ từ Redmine (#{cfg[:identifier]}).",
        redmine_project_id: cfg[:identifier],
        product_version: profile[:product_version],
        development_status: profile[:development_status],
        product_info: profile[:product_info],
        test_plan: profile[:test_plan]
      )

      # Gán thành viên (project_users) theo PROJECT_MEMBERS — không project nào "all".
      member_idxs = Seeds::ContentLibrary::PROJECT_MEMBERS[cfg[:identifier]] || []
      project.users = member_idxs.map { |i| users[i] }
      puts "  Thành viên: #{member_idxs.size} user (#{member_idxs.map { |i| "user#{i}" }.join(', ')})"

      stats = Seeds::ProjectBuilder.new(
        project: project, mode: cfg[:mode], users: project.users.to_a,
        time_window: TIME_WINDOW, root_specs: root_specs
      ).build!
      summarize(project.name, stats)
    end
  end
else
  puts "\n[seed] Thiếu #{json_path} → chỉ tạo users, BỎ QUA 3 project demo."
  puts '[seed] Seed đầy đủ: chạy bootstrap + script/seed_redmine.rb trước (xem docs/SEED_DATA.md).'
end

# ---------------------------------------------------------------------------
# 6. Tổng kết
# ---------------------------------------------------------------------------
puts "\n=== Seed hoàn tất ==="
puts "Projects: #{Project.count} | Tasks: #{Task.count} | TestCases: #{TestCase.count}"
puts "TestSteps: #{TestStep.count} | StepContents: #{TestStepContent.count}"
puts "TestRuns: #{TestRun.count} | TestResults: #{TestResult.count}"
puts "Bugs: #{Bug.count} | BugComments: #{BugComment.count} | BugEvidences: #{BugEvidence.count}"
puts "ActivityLogs: #{ActivityLog.count} (kỳ vọng 0 — Current.user nil khi seed)"
