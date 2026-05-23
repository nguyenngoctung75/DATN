# Demo script để test import functionality
# Run with: rails demo:import_from_redmine[issue_id] hoặc rails demo:import_test_cases[task_id,spreadsheet_id]

namespace :demo do
  desc 'Demo import task từ Redmine - Usage: rails demo:import_from_redmine[12345]'
  task :import_from_redmine, [ :issue_id ] => :environment do |_t, args|
    issue_id = args[:issue_id]

    if issue_id.blank?
      puts '❌ Vui lòng cung cấp Issue ID từ Redmine'
      puts 'Usage: rails demo:import_from_redmine[12345]'
      exit 1
    end

    puts '=' * 80
    puts '🚀 DEMO IMPORT TASK TỪ REDMINE'
    puts '=' * 80
    puts ''

    # Tạo hoặc tìm project demo
    project = Project.find_or_create_by!(name: 'Demo Project') do |p|
      p.description = 'Project demo để test import'
    end
    puts "✅ Project: #{project.name} (ID: #{project.id})"
    puts ''

    # Import task từ Redmine
    puts "📥 Đang import task từ Redmine (Issue ##{issue_id})..."
    service = RedmineImportService.new(issue_id, project.id)

    if service.import
      task = service.task
      puts '✅ Import task thành công!'
      puts ''
      puts '📋 THÔNG TIN TASK:'
      puts "   - ID: #{task.id}"
      puts "   - Title: #{task.title}"
      puts "   - Status: #{task.status}"
      puts "   - Start Date: #{task.start_date}"
      puts "   - Due Date: #{task.due_date}"
      puts "   - Estimated Time: #{task.estimated_time} giờ" if task.estimated_time
      puts "   - Testcase Link: #{task.testcase_link}" if task.testcase_link.present?
      puts "   - Số Test Cases: #{task.number_of_test_cases}"
      puts ''

      if task.test_cases.any?
        puts "🧪 TEST CASES (#{task.test_cases.count}):"
        task.test_cases.limit(5).each_with_index do |tc, index|
          puts ''
          puts "   #{index + 1}. #{tc.title}"
          puts "      - Type: #{tc.test_type}"
          puts "      - Target: #{tc.target}"
          puts "      - Function: #{tc.function}" if tc.function.present?
          puts "      - Steps: #{tc.test_steps.count}"

          # Hiển thị first step
          next unless tc.test_steps.any?

          first_step = tc.test_steps.ordered.first
          puts '      - First Step Actions:'
          first_step.action_contents.limit(2).each do |content|
            puts "        • #{content.content_value}"
          end
        end

        if task.test_cases.count > 5
          puts ''
          puts "   ... và #{task.test_cases.count - 5} test cases khác"
        end
      else
        puts 'ℹ️  Không có test cases nào được import'
      end

      puts ''
      puts '=' * 80
      puts '✨ HOÀN THÀNH!'
      puts '=' * 80
    else
      puts '❌ Import thất bại!'
      puts ''
      puts 'LỖI:'
      service.errors.each do |error|
        puts "   - #{error}"
      end
    end
  end

  desc 'Demo import test cases từ Google Sheet - Usage: rails demo:import_test_cases[task_id,spreadsheet_id]'
  task :import_test_cases, %i[task_id spreadsheet_id] => :environment do |_t, args|
    task_id = args[:task_id]
    spreadsheet_id = args[:spreadsheet_id]

    if task_id.blank?
      puts '❌ Vui lòng cung cấp Task ID'
      puts 'Usage: rails demo:import_test_cases[1,1ABC123xyz]'
      exit 1
    end

    puts '=' * 80
    puts '🚀 DEMO IMPORT TEST CASES TỪ GOOGLE SHEET'
    puts '=' * 80
    puts ''

    # Tìm task
    task = Task.find_by(id: task_id)

    unless task
      puts "❌ Không tìm thấy Task với ID: #{task_id}"
      exit 1
    end

    puts "✅ Task: #{task.title} (ID: #{task.id})"
    puts ''

    # Lấy spreadsheet_id
    sheet_id = spreadsheet_id.presence || task.testcase_link

    if sheet_id.blank?
      puts '❌ Không có Spreadsheet ID'
      puts "Usage: rails demo:import_test_cases[#{task_id},1ABC123xyz]"
      puts 'Hoặc cập nhật task.testcase_link trước'
      exit 1
    end

    # Tạo user demo
    user = User.first || User.create!(
      name: 'Demo User',
      email: 'demo@example.com'
    )

    # Import test cases
    puts '📥 Đang import test cases từ Google Sheet...'
    puts "   Spreadsheet ID: #{sheet_id}"
    puts ''

    service = TestCaseImportService.new(task, sheet_id, user)

    if service.import
      puts '✅ Import thành công!'
      puts ''
      puts '📊 KẾT QUẢ:'
      puts "   - Imported: #{service.imported_count} test cases"
      puts "   - Skipped: #{service.skipped_count} rows"
      puts ''

      if service.errors.any?
        puts '⚠️  WARNINGS:'
        service.errors.first(5).each do |error|
          puts "   - #{error}"
        end
        puts "   ... và #{service.errors.count - 5} warnings khác" if service.errors.count > 5
        puts ''
      end

      # Cập nhật task
      task.update(number_of_test_cases: service.imported_count)

      # Hiển thị mẫu test cases
      if task.test_cases.any?
        puts '🧪 SAMPLE TEST CASES:'
        task.test_cases.limit(3).each_with_index do |tc, index|
          puts ''
          puts "   #{index + 1}. #{tc.title}"
          puts "      Type: #{tc.test_type} | Target: #{tc.target}"

          tc.test_steps.ordered.each do |step|
            puts ''
            puts "      Step #{step.step_number}:"
            puts '        Actions:'
            step.action_contents.each do |content|
              puts "          • #{content.content_value}"
            end
            puts '        Expected:'
            step.expected_contents.each do |content|
              puts "          • #{content.content_value}"
            end
          end
        end

        if task.test_cases.count > 3
          puts ''
          puts "   ... và #{task.test_cases.count - 3} test cases khác"
        end
      end

      puts ''
      puts '=' * 80
      puts '✨ HOÀN THÀNH!'
      puts '=' * 80
    else
      puts '❌ Import thất bại!'
      puts ''
      puts 'LỖI:'
      service.errors.each do |error|
        puts "   - #{error}"
      end
    end
  end

  desc 'Demo tạo test case thủ công - Usage: rails demo:create_manual_test_case[task_id]'
  task :create_manual_test_case, [ :task_id ] => :environment do |_t, args|
    task_id = args[:task_id]

    if task_id.blank?
      puts '❌ Vui lòng cung cấp Task ID'
      puts 'Usage: rails demo:create_manual_test_case[1]'
      exit 1
    end

    puts '=' * 80
    puts '🚀 DEMO TẠO TEST CASE THỦ CÔNG'
    puts '=' * 80
    puts ''

    # Tìm task
    task = Task.find_by(id: task_id)

    unless task
      puts "❌ Không tìm thấy Task với ID: #{task_id}"
      exit 1
    end

    puts "✅ Task: #{task.title}"
    puts ''

    # Tạo user demo
    user = User.first || User.create!(
      name: 'Demo User',
      email: 'demo@example.com'
    )

    puts '📝 Đang tạo test case...'

    # Tạo test case
    test_case = task.test_cases.create!(
      title: 'Demo: Test đăng nhập với email hợp lệ',
      description: 'Kiểm tra chức năng đăng nhập với email và password hợp lệ',
      test_type: 'feature',
      function: 'Authentication',
      target: 'pc_sp_app',
      acceptance_criteria_url: 'https://example.com/ac/123',
      user_story_url: 'https://example.com/us/456',
      created_by: user
    )

    puts "✅ Đã tạo test case: #{test_case.title}"
    puts ''

    puts '📋 Đang tạo test steps...'

    # Step 1: Navigate to login page
    step1 = test_case.test_steps.create!(
      step_number: 1,
      description: 'Mở trang đăng nhập'
    )

    step1.test_step_contents.create!([
                                       {
                                         content_type: 'text',
                                         content_value: 'Mở trình duyệt',
                                         content_category: 'action',
                                         display_order: 0
                                       },
                                       {
                                         content_type: 'text',
                                         content_value: 'Truy cập URL: https://example.com/login',
                                         content_category: 'action',
                                         display_order: 1
                                       },
                                       {
                                         content_type: 'text',
                                         content_value: 'Trang login hiển thị đầy đủ form',
                                         content_category: 'expectation',
                                         display_order: 0
                                       },
                                       {
                                         content_type: 'text',
                                         content_value: 'Có 2 input fields: Email và Password',
                                         content_category: 'expectation',
                                         display_order: 1
                                       },
                                       {
                                         content_type: 'text',
                                         content_value: "Có button 'Login'",
                                         content_category: 'expectation',
                                         display_order: 2
                                       }
                                     ])

    # Step 2: Enter credentials
    step2 = test_case.test_steps.create!(
      step_number: 2,
      description: 'Nhập thông tin đăng nhập'
    )

    step2.test_step_contents.create!([
                                       {
                                         content_type: 'text',
                                         content_value: 'Nhập email: test@example.com vào field Email',
                                         content_category: 'action',
                                         display_order: 0
                                       },
                                       {
                                         content_type: 'text',
                                         content_value: 'Nhập password: Test123456 vào field Password',
                                         content_category: 'action',
                                         display_order: 1
                                       },
                                       {
                                         content_type: 'text',
                                         content_value: 'Email được nhập thành công',
                                         content_category: 'expectation',
                                         display_order: 0
                                       },
                                       {
                                         content_type: 'text',
                                         content_value: 'Password được ẩn bằng dấu *',
                                         content_category: 'expectation',
                                         display_order: 1
                                       }
                                     ])

    # Step 3: Submit form
    step3 = test_case.test_steps.create!(
      step_number: 3,
      description: 'Gửi form đăng nhập'
    )

    step3.test_step_contents.create!([
                                       {
                                         content_type: 'text',
                                         content_value: "Click vào button 'Login'",
                                         content_category: 'action',
                                         display_order: 0
                                       },
                                       {
                                         content_type: 'text',
                                         content_value: 'Redirect đến trang Dashboard (URL: /dashboard)',
                                         content_category: 'expectation',
                                         display_order: 0
                                       },
                                       {
                                         content_type: 'text',
                                         content_value: "Hiển thị thông báo: 'Login successful'",
                                         content_category: 'expectation',
                                         display_order: 1
                                       },
                                       {
                                         content_type: 'text',
                                         content_value: "Header hiển thị tên user: 'Test User'",
                                         content_category: 'expectation',
                                         display_order: 2
                                       }
                                     ])

    puts "✅ Đã tạo #{test_case.test_steps.count} steps"
    puts ''

    puts '🎉 TEST CASE ĐÃ TẠO:'
    puts ''
    puts "   ID: #{test_case.id}"
    puts "   Title: #{test_case.title}"
    puts "   Type: #{test_case.test_type}"
    puts "   Target: #{test_case.target}"
    puts "   Function: #{test_case.function}"
    puts ''

    test_case.test_steps.ordered.each do |step|
      puts "   Step #{step.step_number}: #{step.description}"
      puts '      Actions:'
      step.action_contents.each do |content|
        puts "         • #{content.content_value}"
      end
      puts '      Expected Results:'
      step.expected_contents.each do |content|
        puts "         • #{content.content_value}"
      end
      puts ''
    end

    puts '=' * 80
    puts '✨ HOÀN THÀNH!'
    puts '=' * 80
  end

  desc 'Hiển thị tất cả test cases của một task'
  task :show_test_cases, [ :task_id ] => :environment do |_t, args|
    task_id = args[:task_id]

    if task_id.blank?
      puts '❌ Vui lòng cung cấp Task ID'
      puts 'Usage: rails demo:show_test_cases[1]'
      exit 1
    end

    task = Task.find_by(id: task_id)

    unless task
      puts "❌ Không tìm thấy Task với ID: #{task_id}"
      exit 1
    end

    puts '=' * 80
    puts "📋 TEST CASES CỦA TASK: #{task.title}"
    puts '=' * 80
    puts ''
    puts "Tổng số: #{task.test_cases.active.count} test cases"
    puts ''

    task.test_cases.active.includes(:test_steps).each_with_index do |tc, index|
      puts "#{index + 1}. [#{tc.test_type.upcase}] #{tc.title}"
      puts "   Target: #{tc.target} | Function: #{tc.function || 'N/A'}"
      puts "   Steps: #{tc.test_steps.count}"

      tc.test_steps.ordered.limit(1).each do |step|
        puts "   → Step #{step.step_number}: #{step.action_summary[0..80]}..."
      end

      puts ''
    end

    puts '=' * 80
  end

  desc 'Import dự án 1 (106240) - Single sheet import'
  task import_project_1: :environment do
    puts '=' * 80
    puts '🚀 IMPORT DỰ ÁN 1: TCV-web-v2 (Redmine #106240)'
    puts '=' * 80
    puts ''

    # Tạo hoặc tìm project
    project = Project.find_or_create_by!(name: 'TCV-web-v2')
    puts "✅ Project: #{project.name} (ID: #{project.id})"
    puts ''

    # Import task từ Redmine
    puts '📥 Đang import task từ Redmine...'
    service = RedmineImportService.new('106240', project.id)

    if service.import
      task = service.task
      puts '✅ Import thành công!'
      puts ''
      puts '📋 THÔNG TIN TASK:'
      puts "   - ID: #{task.id}"
      puts "   - Title: #{task.title}"
      puts "   - Status: #{task.status}"
      puts "   - Số Test Cases: #{task.number_of_test_cases}"
      puts ''

      if task.test_cases.any?
        puts "🧪 TEST CASES (#{task.test_cases.count}):"
        task.test_cases.limit(10).each_with_index do |tc, index|
          puts "   #{index + 1}. [#{tc.test_type}] #{tc.title}"
          puts "      Function: #{tc.function || 'N/A'}"
          puts "      Steps: #{tc.test_steps.count}"
        end
      else
        puts '⚠️  Chưa có test cases nào được import'
      end
    else
      puts '❌ Import thất bại!'
      puts "Lỗi: #{service.errors.join(', ')}"
    end

    puts ''
    puts '=' * 80
  end

  desc 'Import dự án 2 (101531) - Multi-sheet import (mỗi sheet = 1 subtask)'
  task import_project_2: :environment do
    puts '=' * 80
    puts '🚀 IMPORT DỰ ÁN 2: UsedCar V2 (Redmine #101531)'
    puts '=' * 80
    puts ''

    # Tạo hoặc tìm project
    project = Project.find_or_create_by!(name: 'usedcar_v2')
    puts "✅ Project: #{project.name} (ID: #{project.id})"
    puts ''

    # Import task từ Redmine (hệ thống sẽ tự động xử lý multi-sheet nếu cần)
    puts '📥 Đang import task từ Redmine...'
    service = RedmineImportService.new('101531', project.id)

    if service.import
      parent_task = service.task
      puts '✅ Import thành công!'
      puts ''
      puts '📋 PARENT TASK:'
      puts "   - ID: #{parent_task.id}"
      puts "   - Title: #{parent_task.title}"
      puts "   - Status: #{parent_task.status}"
      puts "   - Tổng Test Cases: #{parent_task.number_of_test_cases}"
      puts ''

      subtasks = parent_task.subtasks
      if subtasks.any?
        puts "📂 SUBTASKS (#{subtasks.count}):"
        subtasks.each_with_index do |subtask, index|
          puts ''
          puts "   #{index + 1}. #{subtask.title}"
          puts "      - ID: #{subtask.id}"
          puts "      - Status: #{subtask.status}"
          puts "      - Test Cases: #{subtask.number_of_test_cases}"

          next unless subtask.test_cases.any?

          puts '      - Top 3 Test Cases:'
          subtask.test_cases.limit(3).each_with_index do |tc, tc_index|
            puts "         #{tc_index + 1}. [#{tc.test_type}] #{tc.title[0..60]}..."
          end
        end
      else
        puts '⚠️  Không có subtasks nào được tạo'
      end

      puts ''
      puts '📊 TỔNG KẾT:'
      puts '   - Parent task: 1'
      puts "   - Subtasks: #{subtasks.count}"
      puts "   - Tổng test cases: #{parent_task.number_of_test_cases}"
    else
      puts '❌ Import thất bại!'
      puts "Lỗi: #{service.errors.join(', ')}"
    end

    puts ''
    puts '=' * 80
  end
end
