class TestCaseImportService
  attr_reader :errors, :imported_count, :skipped_count

  IMPORT_FILTER = {
    header_rows_count: 4,
    filter_column_index: 1,
    valid_filter_values: %w[Feature Data UI]
  }.freeze

  def initialize(task, spreadsheet_id, wipe_existing: false, sheet_name_filter: nil)
    @task = task
    @spreadsheet_id = spreadsheet_id
    @wipe_existing = wipe_existing
    @sheet_name_filter = sheet_name_filter
    @google_service = GoogleSheetService.new(@spreadsheet_id)
    @errors = []
    @imported_count = 0
    @skipped_count = 0
  end

  def import
    Rails.logger.info "Start import test cases from Google Sheet: #{@spreadsheet_id}"

    all_sheet_data = fetch_sheet_data_for_import
    return false unless all_sheet_data

    detect_single_sheet_mode!(all_sheet_data)
    wipe_existing_test_cases if @wipe_existing && @errors.empty?
    process_all_sheets(all_sheet_data)
    Rails.logger.info "Import completed: #{@imported_count} test cases"
    true
  rescue StandardError => e
    error_msg = ensure_utf8(e.message)
    @errors << "Import error: #{error_msg}"
    Rails.logger.error "TestCaseImportService Error: #{error_msg}\n#{e.backtrace.join("\n")}"
    false
  end

  private

  def fetch_sheet_data_for_import
    @sheet_name_filter.present? ? fetch_single_sheet_data : fetch_sheet_data
  end

  def fetch_sheet_data
    sheet_names = @google_service.list_sheets.map { |s| s[:title] }
    unless sheet_names.any?
      @errors << 'Cannot get data from Google Sheet'
      return nil
    end

    data = sheet_names.each_with_object({}) do |name, result|
      result[name] = @google_service.fetch_sheet(name: name, filter: IMPORT_FILTER)
    end
    data.empty? ? nil : data
  end

  def fetch_single_sheet_data
    sheet_names = @google_service.list_sheets.map { |s| s[:title] }
    unless sheet_names.any?
      @errors << 'Cannot get sheet names from Google Sheet'
      return nil
    end

    target = sheet_names.find { |n| n.include?(@sheet_name_filter) || n.gsub('#', '').strip == @sheet_name_filter }
    unless target
      Rails.logger.warn "No sheet matching '#{@sheet_name_filter}' in #{sheet_names.length} sheets"
      @errors << "No sheet matching '##{@sheet_name_filter}' found"
      return nil
    end

    Rails.logger.info "Fetching only sheet '#{target}' (filter: #{@sheet_name_filter})"
    data = @google_service.fetch_sheet(name: target, filter: IMPORT_FILTER)
    data ? { target => data } : nil
  end

  def detect_single_sheet_mode!(all_sheet_data)
    if @sheet_name_filter.present?
      @is_single_sheet = true
    else
      valid = all_sheet_data.keys.reject { |n| n.downcase.match?(/summary|template|settings|master|instruction/i) }
      @is_single_sheet = valid.length <= 1
    end
  end

  def wipe_existing_test_cases
    Rails.logger.info "Wiping existing test cases and subtasks for task #{@task.id}"
    ApplicationRecord.transaction do
      @task.test_cases.destroy_all
      @task.subtasks.destroy_all
      @task.update!(number_of_test_cases: 0)
    end
    @imported_count = 0
  end

  def process_all_sheets(all_sheet_data)
    processor = TestCaseImport::RowProcessor.new(@task, is_single_sheet: @is_single_sheet)

    all_sheet_data.each do |sheet_name, sheet_data|
      next if @task.parent_id.present? && !name_match?(@task.title, sheet_name)

      process_sheet(sheet_name, sheet_data, processor)
    end

    @imported_count += processor.imported_count
    @skipped_count += processor.skipped_count
    @errors.concat(processor.errors)
    processor.task_counts.each { |t, count| t.update(number_of_test_cases: count) }
    @task.update(number_of_test_cases: 0) unless processor.task_counts.key?(@task)
  end

  def process_sheet(sheet_name, sheet_data, processor)
    return if sheet_data.nil? || sheet_data.empty?

    Rails.logger.info "Processing sheet: #{ensure_utf8(sheet_name)} with #{sheet_data.length} rows"
    parser = TestCaseImport::SheetMetadataParser.new(sheet_data)
    unless parser.valid?
      Rails.logger.warn "Header row not found in sheet: #{sheet_name}"
      return
    end

    parser.data_rows.each_with_index do |row, index|
      row_number = parser.starting_row_number + index
      processor.process(row, parser.column_mapping, sheet_name, row_number)
    rescue StandardError => e
      error_msg = ensure_utf8(e.message)
      @errors << "Error at row #{row_number} in sheet '#{ensure_utf8(sheet_name)}': #{error_msg}"
      @skipped_count += 1
    end
  end

  def name_match?(task_title, sheet_name)
    return false if task_title.blank? || sheet_name.blank?

    ensure_utf8(task_title).downcase.strip == ensure_utf8(sheet_name).downcase.strip
  end

  def ensure_utf8(str)
    str = str.to_s
    str = str.dup if str.frozen?
    str.force_encoding('UTF-8').scrub
  end
end
