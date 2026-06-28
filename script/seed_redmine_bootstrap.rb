# frozen_string_literal: true

# Bootstrap Redmine container: tạo các Tracker, IssueCustomField, IssuePriority,
# Project và Version cần thiết để khớp cấu trúc dev.zigexn.vn (sample 122608).
# REST API của Redmine KHÔNG hỗ trợ tạo trackers/custom fields → phải chạy
# bằng rails runner bên trong container redmine.
#
# Cách chạy (từ máy host):
#   docker compose exec -T redmine bundle exec rails runner /dev/stdin \
#     < script/seed_redmine_bootstrap.rb

# Issue statuses mirroring the app task statuses (only 'Closed' is a closed state).
NEW_STATUS    = IssueStatus.find_or_create_by!(name: 'New') { |s| s.is_closed = false }
IssueStatus.find_or_create_by!(name: 'Pending') { |s| s.is_closed = false }
IssueStatus.find_or_create_by!(name: 'In Progress') { |s| s.is_closed = false }
IssueStatus.find_or_create_by!(name: 'Resolved') { |s| s.is_closed = false }
IssueStatus.find_or_create_by!(name: 'Waiting Release') { |s| s.is_closed = false }
CLOSED_STATUS = IssueStatus.find_or_create_by!(name: 'Closed') { |s| s.is_closed = true }

TRACKER_SPECS = [
  { name: 'User story', position: 12 },
  { name: 'Task',       position: 8  },
  { name: 'Test',       position: 9  }
].freeze

STORY_CF_SPECS = [
  { name: 'JP Request',       format: 'string' },
  { name: 'PR',               format: 'text'   },
  { name: 'Reviewer',         format: 'string' },
  { name: 'Difficulty Level', format: 'string' },
  { name: 'AI usage',         format: 'string' }
].freeze

TEST_CF_SPECS = [
  { name: 'Testcase Link',        format: 'string' },
  { name: 'Number of test cases', format: 'int'    },
  { name: 'STG Bugs (VN)',        format: 'int'    },
  { name: 'STG Bugs (JP)',        format: 'int'    },
  { name: 'Production Bugs',      format: 'int'    },
  { name: 'Bug Link',             format: 'string' },
  { name: 'AI usage',             format: 'string' }
].freeze

PROJECT_SPECS = [
  { identifier: 'seed-tooltest',
    name: 'Tooltest — Hệ thống Quản lý Test Case',
    description: 'Dự án kiểm thử chính hệ thống Test Case Management Tool (Rails 8 + Hotwire + MySQL + CI/CD).' },
  { identifier: 'seed-mobile-banking',
    name: 'Ứng dụng Mobile Banking',
    description: 'Dự án kiểm thử ứng dụng ngân hàng di động.' },
  { identifier: 'seed-ecommerce-shop',
    name: 'Sàn TMĐT Shop Online',
    description: 'Dự án kiểm thử sàn thương mại điện tử.' },
  { identifier: 'seed-admin-dashboard',
    name: 'Hệ thống Quản trị Admin',
    description: 'Dự án kiểm thử trang quản trị nội bộ.' }
].freeze

SPRINT_NAME = '2026-05'

ActiveRecord::Base.transaction do
  trackers = TRACKER_SPECS.map do |spec|
    Tracker.find_or_create_by!(name: spec[:name]) do |t|
      t.default_status_id = NEW_STATUS.id
      t.position = spec[:position]
    end
  end
  story_tr, task_tr, test_tr = trackers
  puts "Trackers: #{trackers.map { |t| "#{t.name}(##{t.id})" }.join(', ')}"

  def upsert_cf(name, format)
    IssueCustomField.find_or_create_by!(name: name) do |cf|
      cf.field_format = format
      cf.is_for_all = true
      cf.is_filter = true
    end
  end

  def attach(cf, tracker)
    cf.trackers << tracker unless cf.trackers.include?(tracker)
  end

  STORY_CF_SPECS.each do |spec|
    cf = upsert_cf(spec[:name], spec[:format])
    attach(cf, story_tr)
  end

  TEST_CF_SPECS.each do |spec|
    cf = upsert_cf(spec[:name], spec[:format])
    attach(cf, test_tr)
  end

  # 'AI usage' xuất hiện ở cả User Story và Task — gắn thêm vào Task tracker
  ai_usage_cf = IssueCustomField.find_by!(name: 'AI usage')
  attach(ai_usage_cf, task_tr)

  IssuePriority.find_or_create_by!(name: 'Medium') { |p|
 p.is_default = true } unless IssuePriority.exists?(name: 'Medium')

  # Ensure any-status -> any-status workflow transitions exist for the real roles
  # so every app status (incl. custom Pending / Waiting Release) is assignable.
  # Idempotent (find_or_create) — runs every time, no early-exit guard.
  workflow_roles = Role.where(builtin: 0).to_a
  workflow_roles = Role.all.to_a if workflow_roles.empty?
  [ story_tr, task_tr, test_tr ].each do |tr|
    workflow_roles.each do |role|
      IssueStatus.where(is_closed: false).find_each do |from|
        IssueStatus.find_each do |to|
          next if from.id == to.id

          WorkflowTransition.find_or_create_by!(
            tracker_id: tr.id, role_id: role.id,
            old_status_id: from.id, new_status_id: to.id
          )
        end
      end
    end
  end

  # Reset để seed lại sạch: xoá toàn bộ seed project (chỉ các identifier seed-*, KHÔNG
  # đụng project ngoài seed) rồi tạo lại theo thứ tự PROJECT_SPECS (Tooltest đầu tiên).
  # KHÔNG ép Tooltest = id 1: trên Redmine sạch nó tự nhận id 1; trên Redmine đã dùng
  # nó nhận id kế tiếp — kết quả web (sau TRUNCATE) vẫn tất định, chỉ created_at khác máy.
  # Tắt bằng SEED_REDMINE_RESET=0.
  if ENV.fetch('SEED_REDMINE_RESET', '1') == '1'
    seed_ids = %w[seed-tooltest seed-mobile-banking seed-ecommerce-shop seed-admin-dashboard]
    Project.where(identifier: seed_ids).find_each do |old|
      puts "Reset: xoá seed project #{old.identifier} (##{old.id})"
      old.destroy
    end
  end

  projects = PROJECT_SPECS.map do |spec|
    p = Project.find_or_create_by!(identifier: spec[:identifier]) do |pr|
      pr.name        = spec[:name]
      pr.description = spec[:description]
      pr.is_public   = true
    end
    p.trackers = ([ story_tr, task_tr, test_tr ] | p.trackers.to_a)
    p.enabled_module_names = (p.enabled_module_names | %w[issue_tracking])
    p.save!

    Version.find_or_create_by!(project_id: p.id, name: SPRINT_NAME) do |v|
      v.status = 'open'
      v.sharing = 'none'
    end

    p
  end

  puts "Projects: #{projects.map { |p| "#{p.identifier}(##{p.id})" }.join(', ')}"
  puts 'Bootstrap xong.'
end
