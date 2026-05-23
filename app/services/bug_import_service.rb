class BugImportService
  attr_reader :errors, :imported_count, :updated_count

  def initialize(task, spreadsheet_id, wipe_existing: false)
    @task = task
    @spreadsheet_id = spreadsheet_id
    @wipe_existing = wipe_existing
    @google_service = GoogleSheetService.new(@spreadsheet_id)
    @parser = BugImport::RowParser.new
    @mapper = BugImport::AttributeMapper.new
    @errors = []
    @imported_count = 0
    @updated_count = 0
  end

  def import
    Rails.logger.info "Start import bugs from Google Sheet: #{@spreadsheet_id}"
    target_sheets = find_target_sheets
    return false unless target_sheets

    wipe_existing_bugs if @wipe_existing && @errors.empty?

    target_sheets.each do |sheet|
      sheet_data = @google_service.fetch_sheet(name: sheet[:title])
      process_sheet(sheet[:title], sheet_data)
    end

    Rails.logger.info "Import bugs complete: #{@imported_count} imported, #{@updated_count} updated"
    true
  rescue StandardError => e
    error_msg = ensure_utf8(e.message)
    @errors << "Error importing bug: #{error_msg}"
    Rails.logger.error "BugImportService Error: #{error_msg}\n#{e.backtrace.join("\n")}"
    false
  end

  private

  def wipe_existing_bugs
    Rails.logger.info "Wiping existing bugs for task #{@task.id}"
    @task.bugs.active.find_each(&:soft_delete!)
    @imported_count = 0
    @updated_count = 0
  end

  def find_target_sheets
    gid = extract_gid(@task.bug_link)
    sheets_info = @google_service.list_sheets

    if sheets_info.nil? || sheets_info.empty?
      @errors << 'Cannot get sheets info from Google Sheet'
      return nil
    end

    target_sheets = gid.present? ? sheets_info.select { |s| s[:sheet_id] == gid } : [ sheets_info.first ]

    if target_sheets.empty?
      @errors << "Cannot find sheet with gid: #{gid}"
      return nil
    end

    target_sheets
  end

  def process_sheet(sheet_name, sheet_data)
    return if sheet_data.nil? || sheet_data.empty?

    column_mapping = @parser.parse_header(sheet_data[0])

    sheet_data.drop(1).each_with_index do |row, index|
      actual_row = index + 2
      process_bug_row(row, column_mapping)
    rescue StandardError => e
      error_msg = ensure_utf8(e.message)
      @errors << "Error at row #{actual_row} in sheet '#{ensure_utf8(sheet_name)}': #{error_msg}"
      Rails.logger.warn "Skipping row #{actual_row}: #{error_msg}"
    end
  end

  def process_bug_row(row, mapping)
    parsed = @parser.parse_row(row, mapping)
    return if parsed[:content].blank?

    title = parsed[:content].split("\n").first.truncate(200)
    bug = @task.bugs.find_or_initialize_by(title: title)
    bug.assign_attributes(@mapper.map(parsed))
    save_bug(bug)
  end

  def save_bug(bug)
    if bug.new_record?
      @imported_count += 1 if bug.save
    elsif bug.save
      @updated_count += 1
    end
  end

  def extract_gid(url)
    return nil if url.blank?

    match = url.match(/[?&#]gid=([0-9]+)/)
    match[1] if match
  end

  def ensure_utf8(str)
    str = str.to_s
    str = str.dup if str.frozen?
    str.force_encoding('UTF-8').scrub
  end
end
