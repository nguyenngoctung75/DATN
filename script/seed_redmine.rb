#!/usr/bin/env ruby
# frozen_string_literal: true

# Seed data cho Redmine: tạo 3 Project, mỗi Project có 100 Issue.
#
# Yêu cầu ENV:
#   REDMINE_BASE_URL  (vd: http://redmine:3000 khi chạy trong container web,
#                          http://localhost:3001 khi chạy từ máy host)
#   REDMINE_API_KEY   (lấy ở Redmine: My Account -> API access key -> Show)
#
# Chạy:
#   docker compose exec web bundle exec ruby script/seed_redmine.rb
#
# Output: tmp/redmine_seed_output.json (đầu vào cho rake task seed:web)

require 'bundler/setup'
require 'faraday'
require 'json'
require 'fileutils'

BASE_URL = ENV['REDMINE_BASE_URL']
API_KEY  = ENV['REDMINE_API_KEY']

if BASE_URL.to_s.empty? || API_KEY.to_s.empty?
  warn 'Thiếu REDMINE_BASE_URL hoặc REDMINE_API_KEY.'
  warn 'Lấy API key: mở Redmine -> My Account -> "API access key" -> Show.'
  warn 'Sau đó thêm vào .env hoặc export trực tiếp trước khi chạy.'
  exit 1
end

SEED_PROJECTS = [
  {
    identifier: 'seed-mobile-banking',
    name: 'Ứng dụng Mobile Banking',
    description: 'Dự án kiểm thử ứng dụng ngân hàng di động: đăng nhập, chuyển khoản, QR Pay, thẻ tín dụng.',
    theme: :banking
  },
  {
    identifier: 'seed-ecommerce-shop',
    name: 'Sàn TMĐT Shop Online',
    description: 'Dự án kiểm thử sàn thương mại điện tử: tìm kiếm, giỏ hàng, thanh toán, đơn hàng, đánh giá.',
    theme: :ecommerce
  },
  {
    identifier: 'seed-admin-dashboard',
    name: 'Hệ thống Quản trị Admin',
    description: 'Dự án kiểm thử trang quản trị nội bộ: phân quyền, audit log, báo cáo, cấu hình hệ thống.',
    theme: :admin
  }
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

CATEGORY_PREFIX = ['Chức năng', 'UI/UX', 'Validate', 'Permission', 'Edge case', 'Performance'].freeze

def conn
  @conn ||= Faraday.new(url: BASE_URL) do |f|
    f.headers['X-Redmine-API-Key'] = API_KEY
    f.headers['Content-Type'] = 'application/json'
    f.options.timeout = 30
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
  raise "POST #{path} failed: #{res.status} #{res.body}" unless res.success?

  JSON.parse(res.body)
end

def ensure_project(seed)
  existing = get_json("/projects/#{seed[:identifier]}.json")
  if existing
    puts "  [skip] Project '#{seed[:identifier]}' đã tồn tại (id=#{existing['project']['id']})"
    return existing['project']
  end

  data = post_json('/projects.json', project: {
    name: seed[:name],
    identifier: seed[:identifier],
    description: seed[:description],
    is_public: true
  })
  puts "  [created] Project '#{seed[:identifier]}' (id=#{data['project']['id']})"
  data['project']
end

def list_existing_issues(project_identifier)
  issues = []
  offset = 0
  limit = 100
  loop do
    data = get_json('/issues.json',
                    project_id: project_identifier,
                    status_id: '*',
                    limit: limit,
                    offset: offset,
                    sort: 'id:asc')
    break unless data && data['issues']

    issues.concat(data['issues'])
    break if data['issues'].size < limit
    break if issues.size >= data['total_count'].to_i

    offset += limit
  end
  issues
end

def build_subject(theme, seq, nouns)
  category = CATEGORY_PREFIX[(seq - 1) % CATEGORY_PREFIX.size]
  noun = nouns[(seq - 1) % nouns.size]
  scenario_variant = ((seq - 1) / nouns.size) + 1
  suffix = scenario_variant > 1 ? " (kịch bản #{scenario_variant})" : ''
  "4. Testing - ##{seq} [#{category}] #{noun}#{suffix}"
end

def build_description(theme, seq, noun_phrase)
  <<~DESC
    Mô tả nghiệp vụ: kiểm thử "#{noun_phrase}".
    - Pre-condition: user đã đăng nhập với quyền hợp lệ.
    - Mục tiêu: đảm bảo luồng "#{noun_phrase}" hoạt động đúng trên các trình duyệt/thiết bị chính.
    - Theme: #{theme}.
    - Seed seq: #{seq}.
  DESC
end

def create_issues_for(project_record, seed)
  nouns = NOUN_BANK.fetch(seed[:theme])
  target = 100

  existing = list_existing_issues(seed[:identifier])
  existing_matching = existing.select { |i| i['subject'].to_s =~ /\A4\.\s*Testing\s*-\s*#/i }
                              .sort_by { |i| i['id'] }
  if existing_matching.size >= target
    puts "  [skip] đã có #{existing_matching.size} issue khớp pattern, không tạo thêm"
    return existing_matching.first(target).map { |i| { 'id' => i['id'], 'subject' => i['subject'] } }
  end

  created = existing_matching.map { |i| { 'id' => i['id'], 'subject' => i['subject'] } }
  start_seq = existing_matching.size + 1

  (start_seq..target).each do |seq|
    subject = build_subject(seed[:theme], seq, nouns)
    payload = {
      issue: {
        project_id: seed[:identifier],
        subject: subject,
        description: build_description(seed[:theme], seq, nouns[(seq - 1) % nouns.size]),
        tracker_id: 1
      }
    }
    data = post_json('/issues.json', payload)
    created << { 'id' => data['issue']['id'], 'subject' => subject }
    print "\r  [issues] #{seq}/#{target}"
    $stdout.flush
  end
  puts ''
  created
end

puts "Seed Redmine - base=#{BASE_URL}"
output = { 'projects' => [] }

SEED_PROJECTS.each do |seed|
  puts "Project: #{seed[:identifier]}"
  project = ensure_project(seed)
  issues = create_issues_for(project, seed)
  output['projects'] << {
    'identifier' => seed[:identifier],
    'redmine_id' => project['id'],
    'name' => seed[:name],
    'description' => seed[:description],
    'theme' => seed[:theme].to_s,
    'issues' => issues
  }
end

out_path = File.expand_path('../tmp/redmine_seed_output.json', __dir__)
FileUtils.mkdir_p(File.dirname(out_path))
File.write(out_path, JSON.pretty_generate(output))
puts "Đã ghi #{out_path}"
puts "Tổng: #{output['projects'].size} project, #{output['projects'].sum { |p| p['issues'].size }} issue"
