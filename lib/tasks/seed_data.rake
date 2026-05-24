# Seed data cho ứng dụng Web — đồng bộ với Redmine theo tmp/redmine_seed_output.json.
#
# Phụ thuộc: chạy script/seed_redmine.rb trước để có file JSON đầu vào.
#
# Sử dụng:
#   docker compose exec web bin/rails seed:web
#   docker compose exec web bin/rails seed:all   # gộp cả 2 phase

namespace :seed do
  TC_SCENARIOS = [
    { suffix: 'trường hợp hợp lệ', note: 'Input đúng, kỳ vọng pass.' },
    { suffix: 'bỏ trống input bắt buộc', note: 'Hệ thống phải hiện cảnh báo "không được để trống".' },
    { suffix: 'sai định dạng dữ liệu', note: 'Ví dụ email thiếu @, số điện thoại có chữ.' },
    { suffix: 'vượt giới hạn độ dài', note: 'Kiểm tra max length của trường input.' },
    { suffix: 'ký tự đặc biệt và emoji', note: 'XSS-safe và lưu Unicode đúng.' },
    { suffix: 'mất kết nối mạng giữa luồng', note: 'Mong đợi retry hoặc thông báo lỗi thân thiện.' },
    { suffix: 'không đủ quyền truy cập', note: 'User role thấp phải bị từ chối.' },
    { suffix: 'dữ liệu trùng/đã tồn tại', note: 'Hệ thống phải hiển thị thông báo trùng và không tạo bản ghi mới.' },
    { suffix: 'phân trang và sắp xếp', note: 'Kiểm tra page size, next/prev và sort order.' },
    { suffix: 'responsive trên mobile', note: 'Layout không vỡ ở viewport 360x640.' }
  ].freeze

  TC_TARGETS = %w[web mobile api].freeze

  desc 'Seed Web app từ tmp/redmine_seed_output.json'
  task web: :environment do
    json_path = Rails.root.join('tmp/redmine_seed_output.json')
    abort "Không tìm thấy #{json_path}. Hãy chạy 'ruby script/seed_redmine.rb' trước." unless File.exist?(json_path)

    data = JSON.parse(File.read(json_path))
    summary = []

    data['projects'].each do |proj|
      identifier = proj['identifier']
      issues = proj['issues']
      raise "Project #{identifier} cần đúng 100 issue, hiện có #{issues.size}" if issues.size != 100

      ActiveRecord::Base.transaction do
        # Cleanup thủ công TestStepContent trước khi destroy Project: model
        # TestCase khai báo has_many :test_steps, dependent: :delete_all —
        # delete_all bỏ qua FK cascade nên TestStepContent (FK step_id ->
        # test_steps.id, không có ON DELETE CASCADE) sẽ orphan và gây
        # ActiveRecord::InvalidForeignKey khi MySQL xoá test_steps.
        # Các bảng có FK -> tasks.id nhưng không khai báo cascade từ phía Task:
        #   - ci_builds.task_id  → nullify (CiBuild#task optional: true)
        # Các bảng cascade qua dependent: :delete_all bỏ qua FK xuống cấp sâu:
        #   - test_cases → test_steps (delete_all) → test_step_contents (FK chặn)
        old_project_ids = Project.where(redmine_project_id: identifier).pluck(:id)
        if old_project_ids.any?
          old_task_ids = Task.where(project_id: old_project_ids).pluck(:id)
          old_tc_ids   = TestCase.where(task_id: old_task_ids).pluck(:id)
          old_step_ids = TestStep.where(case_id: old_tc_ids).pluck(:id)
          TestStepContent.where(step_id: old_step_ids).delete_all if old_step_ids.any?
          CiBuild.where(task_id: old_task_ids).update_all(task_id: nil) if old_task_ids.any?
          Project.where(id: old_project_ids).destroy_all
        end

        project = Project.create!(
          name: proj['name'],
          description: proj['description'],
          redmine_project_id: identifier
        )

        root_count = 0
        sub_count = 0
        tc_count = 0

        issues.first(50).each do |iss|
          task = project.tasks.create!(
            redmine_id: iss['id'],
            title: iss['subject'],
            status: 'new',
            description: "Đồng bộ từ Redmine issue ##{iss['id']}."
          )
          tc_count += seed_test_cases(task, iss['subject'])
          root_count += 1
        end

        issues.last(50).each do |iss|
          root = project.tasks.create!(
            redmine_id: iss['id'],
            title: iss['subject'],
            status: 'new',
            description: "Đồng bộ từ Redmine issue ##{iss['id']} — có 5 subtask."
          )
          root_count += 1

          5.times do |k|
            sub = project.tasks.create!(
              parent_id: root.id,
              title: "#{iss['subject']} — Subtask #{k + 1}",
              status: 'new',
              description: "Subtask #{k + 1} thuộc Task ##{iss['id']}."
            )
            tc_count += seed_test_cases(sub, sub.title)
            sub_count += 1
          end
        end

        summary << { identifier: identifier, name: project.name,
                     root: root_count, sub: sub_count, tc: tc_count }
      end

      puts "[done] #{identifier}"
    end

    puts ''
    puts 'Tổng kết:'
    summary.each do |s|
      puts "  - #{s[:identifier]} (#{s[:name]}): root=#{s[:root]}, sub=#{s[:sub]}, testcase=#{s[:tc]}"
    end
  end

  desc 'Chạy cả 2 phase: seed Redmine + seed Web'
  task all: :environment do
    sh 'bundle exec ruby script/seed_redmine.rb'
    Rake::Task['seed:web'].invoke
  end

  def seed_test_cases(task, context_title)
    base = context_title.to_s.sub(/\A4\.\s*Testing\s*-\s*#\d+\s*/, '').strip
    base = base.sub(/\A\[[^\]]+\]\s*/, '')
    TC_SCENARIOS.each_with_index do |sc, i|
      task.test_cases.create!(
        title: "TC#{i + 1}: #{base} — #{sc[:suffix]}",
        description: "Kịch bản kiểm thử cho '#{base}' (#{sc[:suffix]}).",
        test_type: 'functional',
        target: TC_TARGETS[i % TC_TARGETS.size],
        note: sc[:note],
        position: i + 1
      )
    end
    TC_SCENARIOS.size
  end
end
