#!/usr/bin/env ruby
# frozen_string_literal: true

# Seed Redmine: tạo 3 Project, mỗi Project có 100 User Story (parent) + 6 children
# (Requirement, Design, Coding, Testing, Bug fixing, Release) theo cấu trúc của
# dev.zigexn.vn (sample issue 122608).
#
# Yêu cầu:
#   1) Đã chạy bootstrap để có sẵn trackers/custom fields/projects:
#        docker compose exec -T redmine bundle exec rails runner /dev/stdin \
#          < script/seed_redmine_bootstrap.rb
#   2) ENV REDMINE_BASE_URL + REDMINE_API_KEY (admin)
#
# Chạy:
#   docker compose exec web bundle exec ruby script/seed_redmine.rb
#
# Output: tmp/redmine_seed_output.json — chỉ liệt kê các "4. Testing - #..." child
# (cái mà web app sẽ import qua RedmineBulkImportService). Schema giữ nguyên
# nên lib/tasks/seed_data.rake không cần đổi.

require 'bundler/setup'
require 'faraday'
require 'json'
require 'fileutils'
require 'date'

BASE_URL = ENV['REDMINE_BASE_URL']
API_KEY  = ENV['REDMINE_API_KEY']

if BASE_URL.to_s.empty? || API_KEY.to_s.empty?
  warn 'Thiếu REDMINE_BASE_URL hoặc REDMINE_API_KEY.'
  exit 1
end

SEED_PROJECTS = [
  { identifier: 'seed-mobile-banking', theme: :banking,
    feature_groups: [ 'Auth', 'Transfer', 'Card', 'Bill', 'Savings' ] },
  { identifier: 'seed-ecommerce-shop', theme: :ecommerce,
    feature_groups: [ 'Search', 'Cart', 'Checkout', 'Order', 'Review' ] },
  { identifier: 'seed-admin-dashboard', theme: :admin,
    feature_groups: [ 'RBAC', 'Audit', 'Report', 'Config', 'Notification' ] }
].freeze

NOUN_BANK = {
  banking: [
    'đăng nhập bằng vân tay', 'đăng nhập bằng Face ID', 'quên mật khẩu OTP',
    'đổi mật khẩu trong app', 'chuyển khoản nội bộ', 'chuyển khoản liên ngân hàng 24/7',
    'chuyển khoản theo lịch hẹn', 'quét QR Pay VietQR', 'nạp tiền điện thoại',
    'thanh toán hóa đơn điện', 'thanh toán hóa đơn nước', 'thanh toán hóa đơn internet',
    'tra cứu số dư tài khoản', 'lịch sử giao dịch 30 ngày', 'lịch sử giao dịch 90 ngày',
    'mở thẻ tín dụng online', 'kích hoạt thẻ vật lý', 'khóa thẻ tạm thời',
    'mở khóa thẻ', 'đăng ký gói tiết kiệm online', 'rút tiền tiết kiệm trước hạn',
    'gửi tiết kiệm theo kỳ hạn', 'mua bảo hiểm tai nạn', 'tra cứu lãi suất',
    'đăng ký vay tiêu dùng', 'trả góp hóa đơn', 'liên kết ví điện tử',
    'rút tiền tại ATM bằng QR', 'thông báo biến động số dư', 'thiết lập hạn mức giao dịch'
  ],
  ecommerce: [
    'tìm kiếm sản phẩm theo từ khóa', 'lọc sản phẩm theo giá', 'lọc theo thương hiệu',
    'sắp xếp theo bán chạy', 'sắp xếp theo mới nhất', 'thêm sản phẩm vào giỏ hàng',
    'cập nhật số lượng trong giỏ', 'xóa sản phẩm khỏi giỏ', 'áp mã giảm giá',
    'chọn voucher freeship', 'thanh toán bằng thẻ Visa', 'thanh toán bằng MoMo',
    'thanh toán COD', 'thanh toán bằng ZaloPay', 'đặt hàng nhiều sản phẩm',
    'xem chi tiết đơn hàng', 'hủy đơn hàng trước khi đóng gói', 'theo dõi vận đơn',
    'đánh giá sản phẩm sau mua', 'gửi khiếu nại đơn hàng', 'yêu cầu trả hàng',
    'yêu cầu hoàn tiền', 'đăng ký tài khoản bằng email', 'đăng ký bằng số điện thoại',
    'đăng nhập bằng Google', 'đăng nhập bằng Facebook', 'cập nhật địa chỉ giao hàng',
    'thêm địa chỉ mới', 'chat với shop', 'theo dõi shop', 'xem livestream sản phẩm'
  ],
  admin: [
    'phân quyền theo role', 'tạo role mới', 'gán role cho user',
    'gỡ quyền của user', 'audit log thao tác xóa', 'audit log thao tác sửa',
    'export báo cáo CSV', 'export báo cáo Excel', 'lọc báo cáo theo khoảng thời gian',
    'lọc báo cáo theo phòng ban', 'cấu hình SMTP gửi mail', 'cấu hình SSO',
    'bật xác thực 2 lớp', 'tắt tài khoản user', 'khóa tài khoản sau N lần sai mật khẩu',
    'đặt lại mật khẩu cho user', 'tạo dashboard tùy biến', 'pin widget lên dashboard',
    'tạo lịch chạy job định kỳ', 'dừng job đang chạy', 'xem log lỗi hệ thống',
    'cấu hình ngưỡng cảnh báo', 'gửi notification broadcast', 'quản lý template email',
    'import danh sách user từ CSV', 'sao lưu database thủ công', 'khôi phục từ backup',
    'cấu hình rate limit API', 'quản lý API token', 'thu hồi API token'
  ]
}.freeze

PHASES = [
  { idx: 1, name: 'Requirement', tracker: 'Task' },
  { idx: 2, name: 'Design',      tracker: 'Task' },
  { idx: 3, name: 'Coding',      tracker: 'Task' },
  { idx: 4, name: 'Testing',     tracker: 'Test' },
  { idx: 5, name: 'Bug fixing',  tracker: 'Task' },
  { idx: 6, name: 'Release',     tracker: 'Task' }
].freeze

SPRINT_NAME = '2026-05'
SEQ_BASE    = 1000   # GitHub-style number used in subject "#1001 .. #1100"

def conn
  @conn ||= Faraday.new(url: BASE_URL) do |f|
    f.headers['X-Redmine-API-Key'] = API_KEY
    f.headers['Content-Type'] = 'application/json'
    f.options.timeout = 60
    f.options.open_timeout = 10
    f.adapter Faraday.default_adapter
  end
end

def get_json(path, params = {})
  res = conn.get(path, params)
  return nil if res.status == 404
  raise "GET #{path} failed: #{res.status} #{res.body}" unless res.success?

  JSON.parse(res.body)
end

def post_json(path, payload)
  res = conn.post(path) { |r| r.body = JSON.generate(payload) }
  raise "POST #{path} failed: #{res.status} #{res.body[0, 500]}" unless res.success?

  JSON.parse(res.body)
end

# ---------- Lookup ----------

def lookup_ids
  trackers = get_json('/trackers.json')['trackers']
  statuses = get_json('/issue_statuses.json')['issue_statuses']

  tr = ->(name) { trackers.find { |t|
 t['name'] == name }&.dig('id') or abort("Tracker '#{name}' chưa có. Chạy bootstrap script.") }
  st = ->(name) { statuses.find { |s| s['name'] == name }&.dig('id') or abort("Status '#{name}' chưa có.") }

  {
    tracker: { 'User story' => tr['User story'], 'Task' => tr['Task'], 'Test' => tr['Test'] },
    status:  { 'New' => st['New'] }
  }
end

def project_id_for(identifier)
  data = get_json("/projects/#{identifier}.json")
  abort("Project '#{identifier}' chưa có. Chạy bootstrap script.") unless data

  data['project']['id']
end

def version_id_for(project_identifier, sprint_name)
  data = get_json("/projects/#{project_identifier}/versions.json")
  v = data['versions'].find { |x| x['name'] == sprint_name }
  v&.dig('id')
end

# ---------- Build subjects/payloads ----------

def title_phrase(theme, seq, feature_groups)
  noun = NOUN_BANK.fetch(theme)[(seq - 1) % NOUN_BANK.fetch(theme).size]
  group = feature_groups[(seq - 1) % feature_groups.size]
  "【#{group}】#{noun.capitalize}"
end

def story_subject(github_seq, phrase) = "##{github_seq} #{phrase}"

def child_subject(phase, github_seq, phrase)
  "#{phase[:idx]}. #{phase[:name]} - ##{github_seq} #{phrase}"
end

def story_payload(project_id, tracker_id, status_id, version_id, github_seq, phrase)
  {
    issue: {
      project_id: project_id,
      tracker_id: tracker_id,
      status_id:  status_id,
      subject:    story_subject(github_seq, phrase),
      description: "Seed user story. GitHub ref: https://github.com/seed/repo/issues/#{github_seq}",
      fixed_version_id: version_id,
      start_date: '2026-05-08',
      due_date:   '2026-05-22',
      custom_fields: [
        { id: cf_id('JP Request'),       value: "https://github.com/seed/repo/issues/#{github_seq}" },
        { id: cf_id('PR'),               value: "https://github.com/seed/repo/pull/#{github_seq + 500}" },
        { id: cf_id('Reviewer'),         value: '' },
        { id: cf_id('Difficulty Level'), value: ((github_seq % 5) + 1).to_s },
        { id: cf_id('AI usage'),         value: '' }
      ]
    }
  }
end

def task_child_payload(project_id, tracker_id, status_id, version_id, parent_id, subject)
  {
    issue: {
      project_id: project_id,
      tracker_id: tracker_id,
      status_id:  status_id,
      parent_issue_id: parent_id,
      subject:    subject,
      fixed_version_id: version_id,
      start_date: '2026-05-08',
      due_date:   '2026-05-15'
    }
  }
end

def testing_child_payload(project_id, tracker_id, status_id, version_id, parent_id, subject, seq)
  {
    issue: {
      project_id: project_id,
      tracker_id: tracker_id,
      status_id:  status_id,
      parent_issue_id: parent_id,
      subject:    subject,
      fixed_version_id: version_id,
      start_date: '2026-05-12',
      due_date:   '2026-05-19',
      estimated_hours: 16,
      custom_fields: [
        { id: cf_id('Testcase Link'),
          value: "https://docs.google.com/spreadsheets/d/SEED_SHEET_#{seq}/edit#gid=0" },
        { id: cf_id('Number of test cases'), value: (40 + (seq % 30)).to_s },
        { id: cf_id('STG Bugs (VN)'),        value: (seq % 5).to_s },
        { id: cf_id('STG Bugs (JP)'),        value: (seq % 3).to_s },
        { id: cf_id('Production Bugs'),      value: '0' },
        { id: cf_id('Bug Link'),             value: '' },
        { id: cf_id('AI usage'),             value: '' }
      ]
    }
  }
end

def cf_id(name)
  @cf_cache ||= begin
    list = get_json('/custom_fields.json')
    raise 'Không liệt kê được custom_fields (API yêu cầu admin key)' unless list

    list['custom_fields'].each_with_object({}) { |cf, h| h[cf['name']] = cf['id'] }
  end
  @cf_cache.fetch(name) { abort("Custom field '#{name}' chưa có. Chạy bootstrap script.") }
end

# ---------- Idempotency ----------

def existing_stories(project_identifier, story_tracker_id)
  issues = []
  offset = 0
  loop do
    data = get_json('/issues.json',
                    project_id: project_identifier, tracker_id: story_tracker_id,
                    status_id: '*', limit: 100, offset: offset, sort: 'id:asc')
    break unless data && data['issues']

    issues.concat(data['issues'])
    break if data['issues'].size < 100 || issues.size >= data['total_count'].to_i

    offset += 100
  end
  issues.select { |i| i['subject'].to_s =~ /\A#\d+ / }
end

def existing_testing_children(parent_id, test_tracker_id)
  data = get_json('/issues.json',
                  parent_id: parent_id, tracker_id: test_tracker_id,
                  status_id: '*', limit: 25)
  data ? data['issues'] : []
end

# ---------- Main ----------

ids = lookup_ids
story_tr = ids[:tracker]['User story']
task_tr  = ids[:tracker]['Task']
test_tr  = ids[:tracker]['Test']
new_st   = ids[:status]['New']

puts "IDs: User story=#{story_tr}, Task=#{task_tr}, Test=#{test_tr}, status New=#{new_st}"

output = { 'projects' => [] }

SEED_PROJECTS.each do |seed|
  identifier = seed[:identifier]
  project_id = project_id_for(identifier)
  version_id = version_id_for(identifier, SPRINT_NAME)
  feature_groups = seed[:feature_groups]
  theme = seed[:theme]

  puts ''
  puts "=== Project #{identifier} (id=#{project_id}, version=#{version_id || 'none'}) ==="

  stories = existing_stories(identifier, story_tr)
  if stories.size >= 100
    puts "  [skip] đã có #{stories.size} User Story, không tạo thêm"
  end

  target = 100
  testing_collect = []

  (1..target).each do |seq|
    github_seq = SEQ_BASE + seq
    phrase = title_phrase(theme, seq, feature_groups)

    story_subj = story_subject(github_seq, phrase)
    story = stories.find { |s| s['subject'] == story_subj }
    if story.nil?
      data = post_json('/issues.json',
                       story_payload(project_id, story_tr, new_st, version_id, github_seq, phrase))
      story_id = data['issue']['id']
    else
      story_id = story['id']
    end

    existing_children = story_id ? existing_testing_children(story_id, test_tr) : []
    needs_full_children = existing_children.empty?

    if needs_full_children
      PHASES.each do |phase|
        subj = child_subject(phase, github_seq, phrase)
        if phase[:tracker] == 'Test'
          data = post_json('/issues.json',
                           testing_child_payload(project_id, test_tr, new_st, version_id, story_id, subj, seq))
          testing_collect << { 'id' => data['issue']['id'], 'subject' => subj }
        else
          post_json('/issues.json',
                    task_child_payload(project_id, task_tr, new_st, version_id, story_id, subj))
        end
      end
    else
      testing_collect << { 'id' => existing_children.first['id'],
                           'subject' => existing_children.first['subject'] }
    end

    print "\r  story #{seq}/#{target}"
    $stdout.flush
  end
  puts ''

  raise "Số Testing thu được #{testing_collect.size} != #{target}" if testing_collect.size != target

  project_full = get_json("/projects/#{identifier}.json")['project']
  output['projects'] << {
    'identifier'  => identifier,
    'redmine_id'  => project_full['id'],
    'name'        => project_full['name'],
    'description' => project_full['description'],
    'theme'       => theme.to_s,
    'issues'      => testing_collect
  }
end

out_path = File.expand_path('../tmp/redmine_seed_output.json', __dir__)
FileUtils.mkdir_p(File.dirname(out_path))
File.write(out_path, JSON.pretty_generate(output))
puts ''
puts "Đã ghi #{out_path}"
puts "Tổng: #{output['projects'].size} project, #{output['projects'].sum { |p| p['issues'].size }} Testing issue"
issues_per_project = output['projects'].first['issues'].size
total = issues_per_project * 7
puts "(mỗi project còn có #{issues_per_project} User Story + 5 sibling task/phase khác = #{total} issue total/project)"
