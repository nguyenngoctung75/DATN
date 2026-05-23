class ManualImportOrchestrator
  attr_reader :tc_count, :bug_count

  def initialize(task, import_run: nil)
    @task = task
    @import_run = import_run
    @tc_count = 0
    @bug_count = 0
  end

  def run
    estimate_total
    import_test_cases
    import_bugs
    self
  end

  private

  def estimate_total
    return unless @import_run

    total = 0
    total += 1 if @task.testcase_link.present?
    total += 1 if @task.bug_link.present?
    @import_run.update_columns(total_count: total) if total.positive?
  end

  def import_test_cases
    return unless @task.testcase_link.present?

    service = TestCaseImportService.new(@task, extract_spreadsheet_id(@task.testcase_link))
    @tc_count = service.imported_count if service.import
    @import_run&.append_log("Test cases imported: #{@tc_count}")
    @import_run&.increment_progress!
  end

  def import_bugs
    return unless @task.bug_link.present?

    service = BugImportService.new(@task, extract_spreadsheet_id(@task.bug_link))
    @bug_count = service.imported_count if service.import
    @import_run&.append_log("Bugs imported: #{@bug_count}")
    @import_run&.increment_progress!
  end

  def extract_spreadsheet_id(url)
    match = url.match(%r{/spreadsheets/d/([a-zA-Z0-9_-]+)})
    match ? match[1] : url
  end
end
