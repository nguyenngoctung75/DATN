module Redmine
  class SubtaskImporter
    SHARED_SPREADSHEET_IDS = %w[
      1yvPy4pD5_Gv_I15xkLwJsTR6Y3iS1vD8fxe_Bzk4kho
      1stxO5v-bIYVzZh6PtvGm8YwU6nyrhddsKA6JdIYHcBI
      1E9zDs5Tx-Ti6Xt5P8blSWtfj980lFWyqwOzVTm_AxD8
    ].freeze

    attr_reader :errors

    def initialize(task, project)
      @task = task
      @project = project
      @errors = []
    end

    def run
      import_subtasks_from_sheets
      import_test_cases_if_available
      import_bugs_if_available
    end

    private

    def import_subtasks_from_sheets
      return unless @task.testcase_link.present?
      return if @task.parent_id.present?
      return if shared_spreadsheet?(@task.testcase_link)

      sheet_names = fetch_sheet_names_for_subtasks
      return unless sheet_names&.length.to_i > 1

      Rails.logger.info "Creating subtasks from #{sheet_names.length} sheets for task: #{@task.id}"
      create_subtasks_from_sheets(sheet_names)
    end

    def fetch_sheet_names_for_subtasks
      spreadsheet_id = extract_spreadsheet_id(@task.testcase_link)
      GoogleSheetService.new(spreadsheet_id).list_sheets.map { |s| s[:title] }
    end

    def create_subtasks_from_sheets(sheet_names)
      sheet_names.each do |name|
        name_utf8 = ensure_utf8(name)
        next if name_utf8.match?(/summary|template|settings|master/i)

        subtask = @task.subtasks.find_or_initialize_by(title: name_utf8)
        subtask.assign_attributes(
          project_id: @project.id,
          description: "Subtask automatic created from sheet: #{name_utf8}",
          status: @task.status,
          start_date: @task.start_date,
          due_date: @task.due_date,
          created_by_name: @task.created_by_name
        )
        subtask.save!
      end
    end

    def import_test_cases_if_available
      return unless @task.testcase_link.present?

      Rails.logger.info "Found testcase link: #{@task.testcase_link}, start import test cases..."

      spreadsheet_id = extract_spreadsheet_id(@task.testcase_link)
      is_shared = shared_spreadsheet?(@task.testcase_link)
      sheet_filter = is_shared ? resolve_sheet_name_from_gid(@task.testcase_link, spreadsheet_id) : nil

      if is_shared && sheet_filter.nil?
        Rails.logger.info '    [SKIP TC] No matching sheet in shared spreadsheet for this task'
        return
      end

      service = TestCaseImportService.new(@task, spreadsheet_id, sheet_name_filter: sheet_filter)
      if service.import
        Rails.logger.info "Import test cases successfully: #{service.imported_count} test cases"
        @task.update(number_of_test_cases: service.imported_count)
      else
        service.errors.each { |err| @errors << ensure_utf8(err) }
        Rails.logger.warn "Import test cases failed: #{service.errors.join(', ')}"
      end
    end

    def import_bugs_if_available
      return unless @task.bug_link.present?

      Rails.logger.info "Found bug link: #{@task.bug_link}, start import bugs..."

      spreadsheet_id = extract_spreadsheet_id(@task.bug_link)
      service = BugImportService.new(@task, spreadsheet_id)

      if service.import
        Rails.logger.info "Import bugs successfully: #{service.imported_count} new, #{service.updated_count} updated"
      else
        service.errors.each { |err| @errors << ensure_utf8(err) }
        Rails.logger.warn "Import bugs failed: #{service.errors.join(', ')}"
      end
    end

    def shared_spreadsheet?(url)
      SHARED_SPREADSHEET_IDS.any? { |id| url.to_s.include?(id) }
    end

    def resolve_sheet_name_from_gid(url, spreadsheet_id)
      return nil unless shared_spreadsheet?(url)

      sheets_info = GoogleSheetService.new(spreadsheet_id).list_sheets
      return nil unless sheets_info

      gid = extract_gid(url)
      if gid
        matched = sheets_info.find { |s| s[:sheet_id] == gid }
        if matched
          Rails.logger.info "    [SHEET] Resolved gid=#{gid} → '#{matched[:title]}'"
          return matched[:title]
        end
      end

      title_match = @task.title.to_s.match(/#(\d+)/)
      if title_match
        issue_num = title_match[1]
        matched = sheets_info.find { |s| s[:title].include?(issue_num) }
        if matched
          Rails.logger.info "    [SHEET] Matched issue ##{issue_num} → '#{matched[:title]}'"
          return matched[:title]
        end
      end

      Rails.logger.info "    [SHEET] No matching sheet found for '#{@task.title.to_s.truncate(50)}'"
      nil
    end

    def extract_gid(url)
      return nil if url.blank?

      match = url.match(/gid=(\d+)/)
      match ? match[1] : nil
    end

    def extract_spreadsheet_id(url)
      return url if url.blank?

      match = url.match(%r{/spreadsheets/d/([a-zA-Z0-9_-]+)})
      match ? match[1] : url
    end

    def ensure_utf8(str)
      str = str.to_s
      str = str.dup if str.frozen?
      str.force_encoding('UTF-8').scrub
    end
  end
end
