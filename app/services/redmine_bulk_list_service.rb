# List Redmine "4. Testing" issues with optional date filter and mark already_imported for a project.
class RedmineBulkListService
  TESTING_SUBJECT_PATTERN = /\A4\.\s*Testing\s*-\s*#/i

  attr_reader :errors, :issues

  def initialize(project_id, issues_url: nil)
    @project = Project.find(project_id)
    @issues_url = issues_url.presence || "#{RedmineService::BASE_URL}/issues.json"
    @errors = []
    @issues = []
  end

  # Returns array of hashes: { id, subject, created_on, updated_on, assigned_to_name, status, already_imported }
  # redmine_project_id: Redmine project ID to filter issues (optional but recommended).
  def list(redmine_project_id: nil, created_on_from: nil, created_on_to: nil, limit: 100)
    Rails.logger.info "List Redmine 4. Testing issues for project #{@project.id}, " \
                      "redmine_project_id=#{redmine_project_id}, date range: #{created_on_from}..#{created_on_to}"

    raw_issues = fetch_all_testing_issues(
      redmine_project_id: redmine_project_id,
      created_on_from: created_on_from,
      created_on_to: created_on_to,
      limit: limit
    )
    return [] if raw_issues.nil?

    imported_ids = @project.tasks
      .where.not(redmine_id: nil).where(parent_id: nil)
      .pluck(:redmine_id).map(&:to_s).to_set
    raw_issues.map { |issue| issue_to_list_hash(issue, imported_ids) }
  rescue StandardError => e
    error_msg = ensure_utf8(e.message)
    @errors << "Error loading list: #{error_msg}"
    Rails.logger.error "RedmineBulkListService Error: #{error_msg}\n#{e.backtrace.join("\n")}"
    []
  end

  private

  def issue_to_list_hash(issue, imported_redmine_ids)
    redmine_id = issue['id'].to_s
    {
      id: issue['id'],
      subject: ensure_utf8(issue['subject'].to_s),
      created_on: issue['created_on'],
      updated_on: issue['updated_on'],
      assigned_to_name: issue.dig('assigned_to', 'name').to_s.presence || '-',
      status: issue.dig('status', 'name').to_s.presence || '-',
      already_imported: imported_redmine_ids.include?(redmine_id),
      parent_id: issue.dig('parent', 'id'),
      parent_subject: issue.dig('parent', 'name')
    }
  end

  def fetch_all_testing_issues(redmine_project_id: nil, created_on_from: nil, created_on_to: nil, limit: 100)
    all_testing_issues = []
    current_offset = 0
    from_str = date_param_to_str(created_on_from)
    to_str = date_param_to_str(created_on_to)
    project_id_param = redmine_project_id.to_s.strip.presence

    loop do
      result = RedmineService.get_issues_list(
        @issues_url,
        limit: limit,
        offset: current_offset,
        project_id: project_id_param,
        created_on_from: from_str,
        created_on_to: to_str
      )
      return nil unless result

      issues_batch = result[:issues] || []
      total_count = result[:total_count] || 0

      all_testing_issues.concat(filter_testing_issues(issues_batch))

      break if current_offset + issues_batch.length >= total_count || issues_batch.empty?

      current_offset += limit
    end

    all_testing_issues
  end

  def filter_testing_issues(issues)
    issues.select do |issue|
      subject = ensure_utf8(issue['subject'].to_s)
      # Check if this issue matches the pattern
      next false unless subject.match?(TESTING_SUBJECT_PATTERN)

      # Check if parent also matches the pattern (if parent exists)
      parent_subject = ensure_utf8(issue.dig('parent', 'name').to_s)
      parent_matches = parent_subject.match?(TESTING_SUBJECT_PATTERN)

      # Include only if parent doesn't match (excludes subtasks OF "4. Testing" tasks)
      !parent_matches
    end
  end

  def date_param_to_str(val)
    return val if val.respond_to?(:strftime)
    val.to_s.presence && Date.parse(val.to_s)
  end

  def ensure_utf8(str)
    str = str.to_s
    str = str.dup if str.frozen?
    str.force_encoding('UTF-8').scrub
  end
end
