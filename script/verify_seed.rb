# frozen_string_literal: true

# Kiểm tra invariant sau khi seed (db/seeds.rb). Chạy:
#   docker compose exec web bin/rails runner script/verify_seed.rb

def check(label, ok)
  puts "#{ok ? '✓' : '✗ FAIL'}  #{label}"
end

puts '== Tổng quan =='
puts "Projects=#{Project.count}, Tasks=#{Task.count}, TestCases=#{TestCase.count}, " \
     "Steps=#{TestStep.count}, Contents=#{TestStepContent.count}, Runs=#{TestRun.count}, " \
     "Results=#{TestResult.count}, Bugs=#{Bug.count}, Comments=#{BugComment.count}, " \
     "Evidences=#{BugEvidence.count}, ActivityLogs=#{ActivityLog.count}"

first = Project.order(:id).first
check("Project #1 là Tooltest (id=#{first&.id})", first&.id == 1 && first.name.include?('Tooltest'))

Project.order(:id).each do |p|
  roots = p.tasks.where(parent_id: nil)
  subs  = p.tasks.where.not(parent_id: nil)
  closed = roots.where(status: 'closed').count
  open   = roots.where.not(status: 'closed').count
  tc     = TestCase.joins(:task).where(tasks: { project_id: p.id }).count

  puts "\n== Project ##{p.id}: #{p.name} =="
  check("200 root task (#{roots.count})", roots.count == 200)
  check("190 closed / 10 open (#{closed}/#{open})", closed == 190 && open == 10)
  check("500 subtask (#{subs.count})", subs.count == 500)
  check("7200 testcase (#{tc})", tc == 7200)

  max_closed = roots.where(status: 'closed').maximum(:created_at)
  min_open   = roots.where.not(status: 'closed').minimum(:created_at)
  check('created_at: mọi open > mọi closed', min_open && max_closed && min_open > max_closed)

  bug_root_ids = Bug.joins(:task).where(tasks: { project_id: p.id }).pluck(:task_id).uniq
  closed_bug = Task.where(id: bug_root_ids, status: 'closed').count
  open_bug   = Task.where(id: bug_root_ids).where.not(status: 'closed').count
  done_bugs  = Bug.joins(:task).where(tasks: { project_id: p.id, status: 'closed' }).where.not(status: 'done').count
  check("bug: task closed có bug=#{closed_bug}, task open có bug=#{open_bug}", true)
  check("mọi bug của task closed đều status=done (vi phạm=#{done_bugs})", done_bugs.zero?)

  # redmine_id: cả 3 project đều lấy id thật từ Redmine
  root_with_redmine = roots.where.not(redmine_id: nil).count
  check("200 root đều có redmine_id thật (#{root_with_redmine})", root_with_redmine == 200)
end

puts "\n== Loại dữ liệu chi tiết =="
tooltest = Project.find(1)
check('Tooltest có TestStep', TestStep.joins(test_case: :task).where(tasks: { project_id: 1 }).exists?)
check('Tooltest có TestRun', TestRun.where(task_id: tooltest.tasks.select(:id)).exists?)
check('Tooltest có TestResult', TestResult.joins(test_case: :task).where(tasks: { project_id: 1 }).exists?)
check('ActivityLog = 0', ActivityLog.count.zero?)
