# frozen_string_literal: true

# Thư viện nội dung cho seed (db/seeds.rb).
#
# Cung cấp dữ liệu "có nội dung cụ thể" để dựng test case / test step /
# test step content / bug cho cả 3 project. Các chuỗi dùng placeholder
# "%{feature}" — ProjectBuilder thay bằng tên chức năng thực tế của task.
module Seeds
  module ContentLibrary
    # Membership map — user indices (1..17, admin excluded) assigned to each seed
    # project. Shared by script/seed_redmine.rb (Redmine memberships) and
    # db/seeds.rb (app project_users) so both sides stay consistent.
    # Overlap is intentional (a tester may work on several projects). No project
    # is open to all users.
    PROJECT_MEMBERS = {
      'seed-tooltest'       => [ 1, 2, 3, 4, 5, 6, 7 ],
      'seed-mobile-banking' => [ 6, 7, 8, 9, 10, 11, 12 ],
      'seed-ecommerce-shop' => [ 11, 12, 13, 14, 15, 16, 17 ]
    }.freeze

    # Fake Product Information + Test Plan per seed project (shown on the project page).
    # rubocop:disable Layout/LineLength
    PROJECT_PROFILES = {
      'seed-tooltest' => {
        product_version: 'v1.4.2',
        development_status: 'testing',
        product_info: {
          'owner' => 'QA Team Lead',
          'release_date' => '2026-07-15',
          'progress' => 72,
          'tech_stack' => 'Rails 8, Hotwire, MySQL 8, Solid Queue, Bootstrap 5',
          'summary' => 'Internal test case management tool integrating Redmine, Google Sheets and CI/CD pipelines.'
        },
        test_plan: {
          'objective' => 'Verify all core test-management features work correctly across supported browsers before the v1.4 release.',
          'scope' => 'Authentication, project/task management, spreadsheet test cases, bug tracking, Redmine import and CI/CD webhooks.',
          'strategy' => 'Risk-based functional testing, regression on each release, automated RSpec + Playwright in CI, manual exploratory for new features.',
          'schedule' => [
            { 'milestone' => 'Test design', 'date' => '2026-06-20' },
            { 'milestone' => 'Test execution', 'date' => '2026-07-01' },
            { 'milestone' => 'Regression', 'date' => '2026-07-10' },
            { 'milestone' => 'Sign-off', 'date' => '2026-07-14' }
          ],
          'entry_criteria' => 'Build deployed to staging; test cases reviewed; seed test data available.',
          'exit_criteria' => 'All critical/high test cases passed; no open blocker/critical bugs; pass rate >= 95%.',
          'risks' => 'Tight release timeline; Redmine API instability; limited device coverage.'
        }
      },
      'seed-mobile-banking' => {
        product_version: 'v2.0.0',
        development_status: 'in_development',
        product_info: {
          'owner' => 'Mobile QA Lead',
          'release_date' => '2026-08-30',
          'progress' => 55,
          'tech_stack' => 'Kotlin (Android), Swift (iOS), REST API',
          'summary' => 'Mobile banking application: transfers, cards, bill payment and savings.'
        },
        test_plan: {
          'objective' => 'Ensure secure and correct money-movement flows on both iOS and Android.',
          'scope' => 'Login/biometrics, internal & interbank transfers, QR pay, bill payment, card management, savings.',
          'strategy' => 'Security-focused testing, transaction-integrity checks, cross-device matrix, performance under load.',
          'schedule' => [
            { 'milestone' => 'Test design', 'date' => '2026-07-25' },
            { 'milestone' => 'Functional execution', 'date' => '2026-08-05' },
            { 'milestone' => 'Security & performance', 'date' => '2026-08-15' },
            { 'milestone' => 'UAT', 'date' => '2026-08-25' }
          ],
          'entry_criteria' => 'API contracts frozen; test accounts provisioned; staging gateway available.',
          'exit_criteria' => 'Zero open high/critical defects; security checklist passed; UAT signed off.',
          'risks' => 'Third-party payment gateway downtime; regulatory changes; device fragmentation.'
        }
      },
      'seed-ecommerce-shop' => {
        product_version: 'v3.1.0',
        development_status: 'released',
        product_info: {
          'owner' => 'E-commerce QA Lead',
          'release_date' => '2026-06-01',
          'progress' => 88,
          'tech_stack' => 'Next.js, Node.js, PostgreSQL',
          'summary' => 'Online marketplace: search, cart, checkout, order tracking and reviews.'
        },
        test_plan: {
          'objective' => 'Validate the end-to-end shopping journey and payment options before the peak-sale season.',
          'scope' => 'Product search/filter, cart, vouchers, multiple payment methods, order tracking, returns/refunds, reviews.',
          'strategy' => 'End-to-end journey testing, payment sandbox verification, load testing for sale events, regression suite.',
          'schedule' => [
            { 'milestone' => 'Test design', 'date' => '2026-05-10' },
            { 'milestone' => 'Execution', 'date' => '2026-05-20' },
            { 'milestone' => 'Load test', 'date' => '2026-05-26' },
            { 'milestone' => 'Go-live check', 'date' => '2026-05-31' }
          ],
          'entry_criteria' => 'Catalog data loaded; payment sandbox keys ready; staging stable.',
          'exit_criteria' => 'Checkout success rate >= 99%; no open critical defects; load test meets SLA.',
          'risks' => 'Payment provider rate limits; inventory sync lag; high traffic spikes.'
        }
      }
    }.freeze
    # rubocop:enable Layout/LineLength

    # 40 chức năng có thật của hệ thống Test Case Management Tool (project Tooltest).
    TOOLTEST_FEATURES = [
      'Đăng nhập Devise giới hạn domain @zigexn.vn',
      'Đăng ký tài khoản nội bộ',
      'Đăng xuất và hết phiên',
      'Phân quyền admin/user qua CanCanCan',
      'Tạo mới Project',
      'Chỉnh sửa thông tin Project',
      'Soft delete Project và cascade xuống Task',
      'Khôi phục (restore) Project đã xoá mềm',
      'Hiển thị cây Task phân cấp parent/subtask',
      'Tạo Task gốc trong Project',
      'Tạo Subtask cho Task',
      'Cập nhật trạng thái Task (new → closed)',
      'Tính phần trăm hoàn thành Task',
      'Giao diện spreadsheet quản lý Test Case',
      'Thêm Test Case mới vào Task',
      'Inline edit nội dung ô Test Case',
      'Xem lịch sử thay đổi cấp ô (cell history)',
      'Revert một ô Test Case về phiên bản cũ',
      'Sắp xếp lại vị trí (position) Test Case',
      'Sao chép (clone) Test Case',
      'Quản lý Test Step và renumber tự động',
      'Thêm nội dung action/expectation cho Test Step',
      'Tạo Test Run cho Task',
      'Ghi nhận Test Result theo từng thiết bị',
      'Tính pass-rate của Test Run',
      'Tạo Bug từ Test Result thất bại',
      'Bình luận trong Bug',
      'Đính kèm evidence ảnh/video cho Bug',
      'Cập nhật vòng đời Bug (new → done)',
      'Import Test Case hàng loạt từ Google Sheet',
      'Hiển thị tiến độ import realtime qua ImportRun',
      'Import bulk issue từ Redmine REST API',
      'Đồng bộ Task với Redmine issue theo redmine_id',
      'Cronjob import Redmine hàng ngày (Solid Queue)',
      'Nhận webhook CI/CD từ GitHub Actions',
      'Xác minh chữ ký HMAC-SHA256 của webhook',
      'Hiển thị toast realtime kết quả CI/CD',
      'Trung tâm thông báo (Notification) per-user',
      'Dashboard Project với biểu đồ pass-rate',
      'Xem nhật ký hoạt động (ActivityLog) polymorphic'
    ].freeze

    # 12 kịch bản kiểm thử — mở rộng từ TC_SCENARIOS trong lib/tasks/seed_data.rake.
    # Mỗi kịch bản kèm các step (action + expectation) có nội dung cụ thể.
    TC_SCENARIOS = [
      {
        suffix: 'luồng hợp lệ (happy path)', test_type: 'functional', target: 'web',
        note: 'Input đúng, kỳ vọng thao tác thành công.',
        steps: [
          { action: 'Mở màn hình "%{feature}" với tài khoản hợp lệ',
            expectation: 'Màn hình hiển thị đầy đủ các thành phần, không có lỗi console' },
          { action: 'Nhập dữ liệu hợp lệ rồi bấm nút xác nhận/Lưu',
            expectation: 'Hệ thống xử lý thành công và hiển thị toast thông báo màu xanh' },
          { action: 'Tải lại trang để kiểm tra dữ liệu đã lưu',
            expectation: 'Dữ liệu vừa thao tác được giữ nguyên sau khi tải lại' }
        ]
      },
      {
        suffix: 'bỏ trống input bắt buộc', test_type: 'functional', target: 'web',
        note: 'Hệ thống phải hiện cảnh báo "không được để trống".',
        steps: [
          { action: 'Để trống các trường bắt buộc của "%{feature}" rồi bấm Lưu',
            expectation: 'Hệ thống chặn submit và hiển thị thông báo trường bắt buộc' },
          { action: 'Quan sát trạng thái form sau khi bị chặn',
            expectation: 'Các trường lỗi được tô viền đỏ, con trỏ focus vào trường đầu tiên bị thiếu' }
        ]
      },
      {
        suffix: 'sai định dạng dữ liệu', test_type: 'functional', target: 'web',
        note: 'Ví dụ email thiếu @, số có chữ, ngày sai format.',
        steps: [
          { action: 'Nhập dữ liệu sai định dạng vào "%{feature}" (vd email thiếu @)',
            expectation: 'Hệ thống báo lỗi định dạng và không lưu bản ghi' },
          { action: 'Sửa lại đúng định dạng rồi bấm Lưu',
            expectation: 'Bản ghi được lưu, thông báo lỗi biến mất' }
        ]
      },
      {
        suffix: 'vượt giới hạn độ dài', test_type: 'boundary', target: 'web',
        note: 'Kiểm tra max length của trường input.',
        steps: [
          { action: 'Nhập chuỗi vượt quá độ dài tối đa cho phép của "%{feature}"',
            expectation: 'Hệ thống cắt bớt hoặc báo lỗi vượt giới hạn, không crash' }
        ]
      },
      {
        suffix: 'ký tự đặc biệt và emoji', test_type: 'security', target: 'web',
        note: 'XSS-safe và lưu Unicode đúng.',
        steps: [
          { action: 'Nhập chuỗi chứa thẻ <script>, ký tự đặc biệt và emoji vào "%{feature}"',
            expectation: 'Nội dung được escape an toàn, không thực thi script (XSS)' },
          { action: 'Mở lại bản ghi vừa tạo',
            expectation: 'Emoji và Unicode hiển thị đúng, không bị vỡ ký tự' }
        ]
      },
      {
        suffix: 'mất kết nối mạng giữa luồng', test_type: 'functional', target: 'web',
        note: 'Mong đợi retry hoặc thông báo lỗi thân thiện.',
        steps: [
          { action: 'Ngắt mạng giữa lúc thao tác "%{feature}" rồi bấm Lưu',
            expectation: 'Hệ thống hiển thị thông báo lỗi mạng thân thiện, không mất dữ liệu đang nhập' },
          { action: 'Khôi phục mạng và thử lại',
            expectation: 'Thao tác hoàn tất thành công sau khi có mạng trở lại' }
        ]
      },
      {
        suffix: 'không đủ quyền truy cập', test_type: 'security', target: 'web',
        note: 'User role thấp phải bị từ chối (CanCanCan).',
        steps: [
          { action: 'Đăng nhập bằng tài khoản role user và truy cập "%{feature}" của admin',
            expectation: 'Hệ thống chặn truy cập và hiển thị thông báo không đủ quyền' }
        ]
      },
      {
        suffix: 'dữ liệu trùng/đã tồn tại', test_type: 'functional', target: 'web',
        note: 'Phải hiển thị thông báo trùng và không tạo bản ghi mới.',
        steps: [
          { action: 'Tạo bản ghi "%{feature}" trùng với bản ghi đã tồn tại',
            expectation: 'Hệ thống báo trùng và không tạo thêm bản ghi mới' }
        ]
      },
      {
        suffix: 'phân trang và sắp xếp', test_type: 'functional', target: 'web',
        note: 'Kiểm tra page size, next/prev và sort order.',
        steps: [
          { action: 'Mở danh sách của "%{feature}" rồi chuyển trang next/prev',
            expectation: 'Dữ liệu mỗi trang đúng page size, không trùng lặp giữa các trang' },
          { action: 'Đổi tiêu chí sắp xếp (tăng/giảm)',
            expectation: 'Danh sách được sắp xếp đúng thứ tự đã chọn' }
        ]
      },
      {
        suffix: 'responsive trên mobile', test_type: 'ui', target: 'mobile',
        note: 'Layout không vỡ ở viewport 360x640.',
        steps: [
          { action: 'Mở "%{feature}" trên viewport 360x640 (mobile)',
            expectation: 'Layout co giãn hợp lý, không tràn ngang, nút bấm chạm được' }
        ]
      },
      {
        suffix: 'cập nhật realtime qua ActionCable', test_type: 'integration', target: 'web',
        note: 'Hai phiên trình duyệt phải đồng bộ không cần F5.',
        steps: [
          { action: 'Mở "%{feature}" trên 2 tab; thao tác thay đổi ở tab 1',
            expectation: 'Tab 2 cập nhật realtime qua WebSocket mà không cần tải lại' },
          { action: 'Ngắt WebSocket và kiểm tra cơ chế polling fallback',
            expectation: 'Dữ liệu vẫn được đồng bộ qua polling sau tối đa vài giây' }
        ]
      },
      {
        suffix: 'kiểm tra phân quyền theo vai trò', test_type: 'security', target: 'api',
        note: 'Admin và user thấy/được thao tác khác nhau.',
        steps: [
          { action: 'Gọi API "%{feature}" lần lượt với token admin và token user',
            expectation: 'Phản hồi tuân thủ đúng quyền: admin đầy đủ, user bị giới hạn' }
        ]
      }
    ].freeze

    # Thiết bị dùng cho TestResult.device.
    DEVICES = [
      'Chrome 120 / Windows 11',
      'Safari 17 / macOS Sonoma',
      'Firefox 121 / Ubuntu 22.04',
      'iPhone 15 / iOS 17',
      'Pixel 8 / Android 14'
    ].freeze

    # Template bug — title dùng placeholder %{feature}.
    BUG_TEMPLATES = [
      { title: 'Không hiển thị thông báo lỗi khi %{feature} thất bại',
        category: 'stg_vn', priority: 'high', bug_type: 'Logic', application: 'web',
        description: 'Khi "%{feature}" thất bại, hệ thống không hiển thị thông báo lỗi rõ ràng cho người dùng.' },
      { title: 'Sai dữ liệu hiển thị sau khi %{feature}',
        category: 'stg_jp', priority: 'normal', bug_type: 'Data', application: 'web',
        description: 'Dữ liệu hiển thị không khớp với dữ liệu đã lưu sau khi thực hiện "%{feature}".' },
      { title: 'Vỡ layout màn hình %{feature} trên màn hình nhỏ',
        category: 'stg_vn', priority: 'low', bug_type: 'UI', application: 'mobile',
        description: 'Giao diện "%{feature}" bị tràn/vỡ bố cục khi xem ở viewport nhỏ.' },
      { title: 'Rò rỉ quyền: user truy cập được %{feature}',
        category: 'new_requirement', priority: 'high', bug_type: 'Security', application: 'web',
        description: 'Tài khoản role user vẫn truy cập được chức năng "%{feature}" lẽ ra chỉ dành cho admin.' },
      { title: 'Hiệu năng chậm khi %{feature} với dữ liệu lớn',
        category: 'prod', priority: 'normal', bug_type: 'Performance', application: 'web',
        description: 'Thao tác "%{feature}" phản hồi chậm bất thường khi số bản ghi lớn.' }
    ].freeze

    # Nội dung bình luận bug mẫu.
    BUG_COMMENTS = [
      'Đã tái hiện được lỗi trên môi trường staging, đính kèm log bên dưới.',
      'Mình đã xác định nguyên nhân, đang chuẩn bị fix.',
      'Đã đẩy bản fix lên nhánh, nhờ tester verify lại giúp.',
      'Verify lại OK trên các thiết bị chính, đóng bug.'
    ].freeze

    # Thay placeholder %{feature} an toàn (không dùng String#% để tránh lỗi ký tự %).
    def self.fill(template, feature)
      template.to_s.gsub('%{feature}', feature.to_s)
    end
  end
end
