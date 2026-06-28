# frozen_string_literal: true

# Pushes app-side data onto the matching Redmine issues so the two systems are
# equivalent:
#   - "4. Testing" issues  -> status, estimated hours, number of test cases, bug
#                             counts (STG VN/JP, Production) and assignee (= app task assignee).
#   - other seed issues    -> an assignee (rotating project member) so every issue
#                             (User story, Requirement, Design, Coding, Bug fixing, Release) has one.
#
# App is the source of truth; run this AFTER db:seed.
#
#   docker exec tool_test_project-web-1 bash -c "cd /rails && bin/rails runner script/sync_redmine_indices.rb"

require 'faraday'
require 'json'
require Rails.root.join('db', 'seeds', 'content_library').to_s

BASE = ENV['REDMINE_BASE_URL']
KEY  = ENV['REDMINE_API_KEY']
abort 'Thiếu REDMINE_BASE_URL / REDMINE_API_KEY.' if BASE.to_s.empty? || KEY.to_s.empty?

conn = Faraday.new(url: BASE) do |f|
  f.headers['X-Redmine-API-Key'] = KEY
  f.headers['Content-Type'] = 'application/json'
  f.options.timeout = 60
  f.options.open_timeout = 10
  f.adapter Faraday.default_adapter
end

def put_issue(conn, id, attrs)
  res = conn.put("/issues/#{id}.json") { |r| r.body = JSON.generate(issue: attrs) }
  res.success?
end

cf = JSON.parse(conn.get('/custom_fields.json').body)['custom_fields'].to_h { |c| [ c['name'], c['id'] ] }
tc_id   = cf.fetch('Number of test cases')
vn_id   = cf.fetch('STG Bugs (VN)')
jp_id   = cf.fetch('STG Bugs (JP)')
prod_id = cf.fetch('Production Bugs')

statuses = JSON.parse(conn.get('/issue_statuses.json').body)['issue_statuses'].to_h { |s| [ s['name'], s['id'] ] }
app_to_redmine = { 'closed' => 'Closed', 'new' => 'New', 'pending' => 'Pending',
                   'in progress' => 'In Progress', 'resolved' => 'Resolved', 'waiting release' => 'Waiting Release' }

# Redmine user login -> id (login "userN" matches app user userN@example.com).
user_by_login = {}
offset = 0
loop do
  data = JSON.parse(conn.get('/users.json', limit: 100, offset: offset, status: '*').body)
  data['users'].each { |u| user_by_login[u['login']] = u['id'] }
  break if data['users'].size < 100

  offset += 100
end
uid_for = ->(email) { user_by_login[email.to_s.split('@').first] }

# ----- Pass 1: testing issues (app tasks) — full equivalence + assignee -----
updated = 0
failed = 0
Task.where.not(redmine_id: nil).where(parent_id: nil).find_each do |task|
  attrs = {
    status_id: statuses[app_to_redmine[task.status]],
    estimated_hours: task.estimated_time.to_f,
    custom_fields: [
      { id: tc_id,   value: task.total_test_cases_count.to_s },
      { id: vn_id,   value: task.stg_bugs_vn.to_i.to_s },
      { id: jp_id,   value: task.stg_bugs_jp.to_i.to_s },
      { id: prod_id, value: task.prod_bugs.to_i.to_s }
    ]
  }
  assignee_uid = task.assignee && uid_for.call(task.assignee.email)
  attrs[:assigned_to_id] = assignee_uid if assignee_uid
  put_issue(conn, task.redmine_id, attrs) ? (updated += 1) : (failed += 1)
  print "\r  testing synced #{updated} (failed #{failed})"
  $stdout.flush
end
puts "\nPass 1: #{updated} testing issue (#{failed} lỗi)."

# ----- Pass 2: every other seed issue gets a (rotating) member assignee -----
assigned = 0
Seeds::ContentLibrary::PROJECT_MEMBERS.each do |identifier, idxs|
  member_uids = idxs.map { |i| user_by_login["user#{i}"] }.compact
  next if member_uids.empty?

  offset = 0
  loop do
    data = JSON.parse(conn.get('/issues.json', project_id: identifier, status_id: '*', limit: 100, offset: offset).body)
    issues = data['issues']
    issues.each do |iss|
      next if iss['tracker']['name'] == 'Test' # handled in pass 1 (app assignee)

      put_issue(conn, iss['id'], assigned_to_id: member_uids[iss['id'] % member_uids.size]) && (assigned += 1)
    end
    break if issues.size < 100

    offset += 100
  end
  print "\r  member-assigned #{assigned}"
  $stdout.flush
end
puts "\nPass 2: #{assigned} issue khác đã gán assignee."
puts 'Đồng bộ Redmine hoàn tất.'
