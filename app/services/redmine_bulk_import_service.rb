# Bulk import tasks from Redmine issues URL.
# Only imports issues where subject matches "4. Testing" (tracker Test, subject starts with "4. Testing")
class RedmineBulkImportService
  TESTING_SUBJECT_PATTERN = /\A4\.\s*Testing\s*-\s*#/i

  attr_reader :errors, :imported_tasks, :skipped_count, :found_count

  def initialize(project_id, issues_url: nil, import_run: nil)
    @project = Project.find(project_id)
    @issues_url = issues_url.presence || "#{RedmineService::BASE_URL}/issues.json"
    @import_run = import_run
    @errors = []
    @imported_tasks = []
    @skipped_count = 0
    @found_count = 0
  end

  def import(limit: 100, offset: 0, issue_ids: nil, &block)
    if issue_ids.present?
      import_by_issue_ids(Array(issue_ids), &block)
    else
      import_all(limit: limit, offset: offset, &block)
    end
  end

  def import_by_issue_ids(issue_ids)
    Rails.logger.info "Start bulk import by issue_ids: #{issue_ids.inspect}"
    issue_ids = issue_ids.map(&:to_s).reject(&:blank?).uniq
    return true if issue_ids.empty?

    @found_count = issue_ids.length
    yield @found_count if block_given?
    @import_run&.update_columns(total_count: @found_count)
    issue_ids.each { |id| process_issue_id(id) }
    Rails.logger.info "Bulk import by IDs completed: #{@imported_tasks.length} tasks imported"
    true
  rescue StandardError => e
    error_msg = ensure_utf8(e.message)
    @errors << "Bulk import error: #{error_msg}"
    Rails.logger.error "RedmineBulkImportService Error: #{error_msg}\n#{e.backtrace.first(5).join("\n")}"
    false
  end

  def import_all(limit: 100, offset: 0)
    Rails.logger.info "Start bulk import from Redmine URL: #{@issues_url} (full pages)"

    testing_issues = fetch_all_testing_issues(limit: limit, offset: offset)
    return false if testing_issues.nil?

    imported_ids = imported_redmine_ids_set
    @found_count = testing_issues.length
    yield @found_count if block_given?
    @import_run&.update_columns(total_count: @found_count)

    return log_no_issues_and_success if testing_issues.empty?

    Rails.logger.info "Found #{testing_issues.length} issues matching '4. Testing', " \
                      'importing (skip already imported)...'
    import_testing_issues_batch(testing_issues, imported_ids)
    log_import_complete
    true
  rescue StandardError => e
    error_msg = ensure_utf8(e.message)
    @errors << "Bulk import error: #{error_msg}"
    Rails.logger.error "RedmineBulkImportService Error: #{error_msg}\n#{e.backtrace.first(5).join("\n")}"
    false
  end

  private

  def process_issue_id(issue_id)
    issue_data = RedmineService.get_issues(issue_id)
    unless issue_data
      @import_run&.increment_progress!
      return
    end
    subject = ensure_utf8(issue_data['subject'].to_s)
    unless subject.match?(TESTING_SUBJECT_PATTERN)
      @skipped_count += 1
      @import_run&.increment_progress!
      return
    end
    import_single_issue(issue_data)
    @import_run&.increment_progress!
  end

  def imported_redmine_ids_set
    @project.tasks.where.not(redmine_id: nil).where(parent_id: nil).pluck(:redmine_id).map(&:to_s).to_set
  end

  def log_no_issues_and_success
    Rails.logger.info 'No "4. Testing" issues found in response'
    true
  end

  def import_testing_issues_batch(testing_issues, imported_ids)
    testing_issues.each do |issue_data|
      redmine_id = issue_data['id'].to_s
      if imported_ids.include?(redmine_id)
        @skipped_count += 1
        @import_run&.increment_progress!
        next
      end
      import_single_issue(issue_data)
      imported_ids.add(redmine_id)
      @import_run&.increment_progress!
    end
  end

  def log_import_complete
    Rails.logger.info "Bulk import completed: #{@imported_tasks.length} imported, " \
                      "#{@skipped_count} skipped (already existed)"
  end

  # Fetch all pages and collect only "4. Testing" issues
  def fetch_all_testing_issues(limit: 100, offset: 0)
    all_testing_issues = []
    current_offset = offset

    loop do
      result = RedmineService.get_issues_list(@issues_url, limit: limit, offset: current_offset)
      return nil unless result

      issues = result[:issues] || []
      total_count = result[:total_count] || 0

      all_testing_issues.concat(filter_testing_issues(issues))

      break if current_offset + issues.length >= total_count || issues.empty?

      current_offset += limit
      Rails.logger.info "Fetched page offset=#{current_offset - limit}, loading next..."
    end

    all_testing_issues
  end

  def filter_testing_issues(issues)
    issues.select do |issue|
      subject = ensure_utf8(issue['subject'].to_s)
      subject.match?(TESTING_SUBJECT_PATTERN)
    end
  end

  def import_single_issue(issue_data)
    import_service = RedmineImportService.new(issue_data['id'].to_s, @project.id)
    import_service.import_from_issue_data(issue_data)
    @imported_tasks << import_service.task if import_service.task
  rescue StandardError => e
    error_msg = ensure_utf8(e.message)
    subject = ensure_utf8(issue_data['subject'])
    @errors << "Issue ##{issue_data['id']} (#{subject}): #{error_msg}"
    @skipped_count += 1
    Rails.logger.warn "Skip issue ##{issue_data['id']}: #{error_msg}"
  end

  def ensure_utf8(str)
    str = str.to_s
    str = str.dup if str.frozen?
    str.force_encoding('UTF-8').scrub
  end
end
