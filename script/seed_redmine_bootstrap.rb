# frozen_string_literal: true

# Bootstrap Redmine container: tạo các Tracker, IssueCustomField, IssuePriority,
# Project và Version cần thiết để khớp cấu trúc dev.zigexn.vn (sample 122608).
# REST API của Redmine KHÔNG hỗ trợ tạo trackers/custom fields → phải chạy
# bằng rails runner bên trong container redmine.
#
# Cách chạy (từ máy host):
#   docker compose exec -T redmine bundle exec rails runner /dev/stdin \
#     < script/seed_redmine_bootstrap.rb

NEW_STATUS = IssueStatus.find_or_create_by!(name: 'New') { |s| s.is_closed = false }

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

  IssuePriority.find_or_create_by!(name: 'Medium') { |p| p.is_default = true } unless IssuePriority.exists?(name: 'Medium')

  default_role = Role.find_by(name: 'Manager') || Role.where(builtin: 0).first
  if default_role
    [story_tr, task_tr, test_tr].each do |tr|
      next if WorkflowTransition.exists?(tracker_id: tr.id, role_id: default_role.id)

      IssueStatus.where(is_closed: false).find_each do |from|
        IssueStatus.find_each do |to|
          next if from.id == to.id

          WorkflowTransition.find_or_create_by!(
            tracker_id: tr.id, role_id: default_role.id,
            old_status_id: from.id, new_status_id: to.id
          )
        end
      end
    end
  end

  projects = PROJECT_SPECS.map do |spec|
    p = Project.find_or_create_by!(identifier: spec[:identifier]) do |pr|
      pr.name        = spec[:name]
      pr.description = spec[:description]
      pr.is_public   = true
    end
    p.trackers = ([story_tr, task_tr, test_tr] | p.trackers.to_a)
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
