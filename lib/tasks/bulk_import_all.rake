# # frozen_string_literal: true

# module BulkImportConfig
#   # Map Redmine project names (as they appear in issue['project']['name']) => local Project names.
#   REDMINE_TO_LOCAL = {
#     'ChukosyaEx V2' => 'ChukosyaEx V2',
#     'New Sell Car' => 'New Sell Car',
#     'TCV' => 'TCV',
#     'Usedcar-EX' => 'Usedcar-EX'
#   }.freeze

#   # Relaxed pattern: matches any subject starting with "4. Testing" (case-insensitive)
#   TESTING_SUBJECT_PATTERN = /\A4\.\s*Testing/i
#   # Exclude "4. Testing - Execute" issues
#   EXCLUDE_SUBJECT_PATTERN = /\A4\.\s*Testing\s*-\s*Execute/i
#   # The umbrella Redmine project that contains all subprojects
#   UMBRELLA_PROJECT = 'usedcar-ex'
#   PAGE_LIMIT = 100
#   SLEEP_BETWEEN_IMPORTS = 2.0 # seconds, higher to avoid Google Sheets RESOURCE_EXHAUSTED

#   module_function

#   # Use project-scoped URL to include subprojects automatically.
#   # Matches: 
#   def issues_url
#     "#{RedmineService::BASE_URL}/projects/#{UMBRELLA_PROJECT}/issues.json"
#   end

#   def ensure_utf8(str)
#     str = str.to_s
#     str = str.dup if str.frozen?
#     str.force_encoding('UTF-8').scrub
#   end

#   def testing_issue?(issue)
#     subject = ensure_utf8(issue['subject'].to_s)
#     subject.match?(TESTING_SUBJECT_PATTERN) && !subject.match?(EXCLUDE_SUBJECT_PATTERN)
#   end

#   # Accepts a pre-built cache to avoid N+1 Project lookups across the pagination loop.
#   def resolve_local_project(issue_data, project_cache)
#     redmine_project_name = issue_data.dig('project', 'name').to_s
#     local_name = REDMINE_TO_LOCAL[redmine_project_name]
#     return nil unless local_name

#     project_cache[local_name]
#   end

#   def import_single_issue(issue_data, project, project_stats)
#     redmine_id = issue_data['id'].to_s
#     subject = ensure_utf8(issue_data['subject'].to_s).truncate(80)

#     if project.tasks.exists?(redmine_id: redmine_id)
#       project_stats[:skipped] += 1
#       puts "    [SKIP] ##{redmine_id}: #{subject} (already imported)"
#       return
#     end

#     service = RedmineImportService.new(redmine_id, project.id)
#     service.import_from_issue_data(issue_data)

#     if service.task
#       record_success(service, project_stats, redmine_id, subject)
#     else
#       record_failure(project_stats, redmine_id, subject, service.errors.join('; '))
#     end
#   rescue StandardError => e
#     error_msg = ensure_utf8(e.message).truncate(200)
#     record_failure(project_stats, redmine_id, subject, error_msg)
#   end

#   def record_success(service, project_stats, redmine_id, subject)
#     tc_count = service.task.test_cases.where(deleted_at: nil).count
#     bug_count = service.task.bugs.where(deleted_at: nil).count
#     project_stats[:imported] += 1
#     project_stats[:test_cases] += tc_count
#     project_stats[:bugs] += bug_count
#     puts "    [OK] ##{redmine_id}: #{subject} (TC: #{tc_count}, Bugs: #{bug_count})"
#   end

#   def record_failure(project_stats, redmine_id, subject, error_msg)
#     project_stats[:failed] += 1
#     project_stats[:errors] << "##{redmine_id}: #{error_msg}"
#     puts "    [FAIL] ##{redmine_id}: #{subject} — #{error_msg}"
#   end

#   def init_stats(selected_project)
#     names = REDMINE_TO_LOCAL.values
#     names = names.select { |n| n.casecmp?(selected_project) } if selected_project
#     names.each_with_object({}) { |name, hash| hash[name] = new_project_stats }
#   end

#   def new_project_stats
#     { found: 0, imported: 0, skipped: 0, failed: 0, test_cases: 0, bugs: 0, errors: [] }
#   end

#   def print_header(dry_run, stats, start_time)
#     puts '=' * 70
#     puts dry_run ? '  DRY RUN — BULK IMPORT FROM REDMINE' : '  BULK IMPORT FROM REDMINE'
#     puts "  Projects: #{stats.keys.join(', ')}"
#     puts "  Started at: #{start_time.strftime('%Y-%m-%d %H:%M:%S')}"
#     puts '=' * 70
#   end

#   # Loads all mapped projects in a single query to avoid N+1 inside the pagination loop.
#   def build_project_cache
#     Project.where(name: REDMINE_TO_LOCAL.values).index_by(&:name)
#   end

#   def paginate_and_import(stats, dry_run, selected_project)
#     offset = 0
#     page = 0
#     unmapped_count = 0
#     project_cache = build_project_cache

#     loop do
#       page += 1
#       result = fetch_issues_page(offset)
#       break unless result

#       issues_batch = result[:issues] || []
#       total_count = result[:total_count] || 0
#       testing_issues = issues_batch.select { |i| testing_issue?(i) }

#       puts "\n  Page #{page}: #{testing_issues.length}/#{issues_batch.length} " \
#            "match '4. Testing' (total in Redmine: #{total_count})"

#       unmapped_count += process_page(testing_issues, stats, dry_run, selected_project, project_cache)

#       break if offset + issues_batch.length >= total_count || issues_batch.empty?

#       offset += PAGE_LIMIT
#       sleep(0.2)
#     end

#     puts "\n  [INFO] #{unmapped_count} issues had unmapped projects (skipped)" if unmapped_count.positive?
#   end

#   def fetch_issues_page(offset)
#     # tracker_id=9 (Test), status_id=c (closed), sort=id:asc imports oldest issues first
#     url = "#{issues_url}?tracker_id=9&status_id=c&sort=id:asc"
#     RedmineService.get_issues_list(url, limit: PAGE_LIMIT, offset: offset)
#   end

#   def process_page(testing_issues, stats, dry_run, selected_project, project_cache)
#     unmapped = 0

#     testing_issues.each do |issue_data|
#       project = resolve_local_project(issue_data, project_cache)

#       unless project
#         unmapped += 1
#         next
#       end

#       next if selected_project && !project.name.casecmp?(selected_project)

#       project_stats = stats[project.name] || (stats[project.name] = new_project_stats)
#       project_stats[:found] += 1

#       process_single_issue(issue_data, project, project_stats, dry_run)
#     end

#     unmapped
#   end

#   def process_single_issue(issue_data, project, project_stats, dry_run)
#     redmine_id = issue_data['id']
#     subject = ensure_utf8(issue_data['subject'].to_s).truncate(80)

#     if dry_run
#       puts "    [DRY RUN] ##{redmine_id} (#{project.name}): #{subject}"
#       project_stats[:imported] += 1
#       return
#     end

#     import_single_issue(issue_data, project, project_stats)
#     sleep(SLEEP_BETWEEN_IMPORTS)
#   end

#   def print_summary(stats, dry_run, duration)
#     puts "\n#{'=' * 70}"
#     puts '  BULK IMPORT SUMMARY REPORT'
#     puts "  Duration: #{duration}s (#{(duration / 60).round(1)} min)"
#     puts '=' * 70

#     total = { found: 0, imported: 0, skipped: 0, failed: 0, test_cases: 0, bugs: 0 }
#     all_errors = []

#     stats.each do |project_name, pstat|
#       print_project_stats(project_name, pstat, dry_run)
#       %i[found imported skipped failed test_cases bugs].each { |k| total[k] += pstat[k] }
#       all_errors.concat(pstat[:errors].map { |e| "#{project_name}: #{e}" })
#     end

#     print_totals(total, dry_run, all_errors)
#   end

#   def print_project_stats(project_name, pstat, dry_run)
#     imported_label = dry_run ? 'Would Import' : 'Imported'
#     puts "\n  Project: #{project_name}"
#     puts "    Found: #{pstat[:found]} | #{imported_label}: #{pstat[:imported]} " \
#          "| Skipped: #{pstat[:skipped]} | Failed: #{pstat[:failed]}"
#     puts "    Test Cases: #{pstat[:test_cases]} | Bugs: #{pstat[:bugs]}" unless dry_run
#   end

#   def print_totals(total, dry_run, all_errors)
#     imported_label = dry_run ? 'Would Import' : 'Imported'
#     puts "\n  TOTAL:"
#     puts "    Found: #{total[:found]} | #{imported_label}: #{total[:imported]} " \
#          "| Skipped: #{total[:skipped]} | Failed: #{total[:failed]}"
#     puts "    Test Cases: #{total[:test_cases]} | Bugs: #{total[:bugs]}" unless dry_run

#     if all_errors.any?
#       puts "\n  ERRORS (#{all_errors.length}):"
#       all_errors.each { |e| puts "    • #{e}" }
#     end

#     puts "\n#{'=' * 70}"
#     puts dry_run ? '  DRY RUN COMPLETE' : '  IMPORT COMPLETE'
#     puts '=' * 70
#   end
# end

# namespace :import do
#   desc "Import '4. Testing' issues from Redmine. Options: PROJECT='name', DRY_RUN=true"
#   task all: :environment do
#     dry_run = ENV['DRY_RUN'] == 'true'
#     selected_project = ENV['PROJECT'].to_s.strip.presence

#     stats = BulkImportConfig.init_stats(selected_project)
#     overall_start = Time.current
#     BulkImportConfig.print_header(dry_run, stats, overall_start)

#     BulkImportConfig.paginate_and_import(stats, dry_run, selected_project)

#     duration = (Time.current - overall_start).round(1)
#     BulkImportConfig.print_summary(stats, dry_run, duration)

#     total_failed = stats.sum { |_, s| s[:failed] }
#     abort "Import finished with #{total_failed} failure(s). See errors above." if total_failed.positive?
#   end
# end
