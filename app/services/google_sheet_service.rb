require 'google/apis/sheets_v4'
require 'googleauth'

class GoogleSheetService
  SCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS_READONLY
  CREDENTIALS_PATH = Rails.root.join('config', 'google_credentials.json')
  QUOTA_RETRY_WAIT = 65
  MAX_RETRIES = 3

  def initialize(spreadsheet_id)
    @spreadsheet_id = spreadsheet_id
    @service = Google::Apis::SheetsV4::SheetsService.new
    @service.authorization = authorize
  end

  # Returns raw rows (Array<Array>) or filtered rows when filter: is given.
  # filter: { header_rows_count:, filter_column_index:, valid_filter_values: }
  def fetch_sheet(name:, range: nil, filter: nil)
    full_range = range ? "#{name}!#{range}" : name
    raw_rows = sheet_values(full_range)
    return nil if raw_rows.nil?
    return raw_rows unless filter

    @current_options = filter
    filter_raw_rows(raw_rows)
  rescue StandardError => e
    Rails.logger.error "GoogleSheetService: Error in fetch_sheet(#{name}): #{e.message}"
    nil
  end

  # Returns all sheets as [{ title: String, sheet_id: String }].
  def list_sheets
    response = with_quota_retry('list_sheets') do
      @service.get_spreadsheet(@spreadsheet_id, fields: 'sheets(properties(title,sheetId))')
    end
    return [] unless response

    response.sheets.map do |sheet|
      { title: ensure_utf8(sheet.properties.title), sheet_id: sheet.properties.sheet_id.to_s }
    end
  end

  private

  def sheet_values(range)
    response = with_quota_retry('fetch_sheet') do
      @service.get_spreadsheet_values(@spreadsheet_id, range)
    end
    return nil unless response

    response.values || []
  end

  # Retry block when Google Sheets quota is exceeded.
  # Waits 65 seconds (quota resets per minute) then retries up to MAX_RETRIES times.
  def with_quota_retry(operation)
    retries = 0
    begin
      yield
    rescue Google::Apis::RateLimitError => e
      retries += 1
      if retries <= MAX_RETRIES
        msg = "GoogleSheetService [QUOTA] #{operation}: Rate limit hit. " \
              "Waiting #{QUOTA_RETRY_WAIT}s... (retry #{retries}/#{MAX_RETRIES})"
        Rails.logger.warn msg
        sleep(QUOTA_RETRY_WAIT)
        retry
      else
        Rails.logger.error "GoogleSheetService [QUOTA] #{operation}: Max retries exceeded. #{e.message}"
        nil
      end
    rescue Google::Apis::Error => e
      Rails.logger.error "GoogleSheetService: Error in #{operation}: #{e.message}"
      nil
    end
  end

  def filter_raw_rows(raw_rows)
    header_rows_count = @current_options.fetch(:header_rows_count, 4)
    filter_column_index = @current_options.fetch(:filter_column_index, 1)
    valid_filter_values = @current_options.fetch(:valid_filter_values, %w[Feature Data UI])

    clean_data = raw_rows.first(header_rows_count)

    if raw_rows.length > header_rows_count
      device_names_row = raw_rows[header_rows_count]
      clean_data << device_names_row
      Rails.logger.debug "GoogleSheetService: Including device names row (row #{header_rows_count + 1})"
    end

    data_rows = raw_rows.drop(header_rows_count + 1)
    filtered_rows = data_rows.filter do |row|
      cell_value = row[filter_column_index]
      cell_value.present? && valid_filter_values.include?(cell_value.strip)
    end

    clean_data.concat(filtered_rows)
    Rails.logger.debug(
      "GoogleSheetService: Filtering completed. Total #{clean_data.length} rows " \
      "(including #{header_rows_count} header rows + 1 device names row)."
    )
    clean_data
  end

  def authorize
    unless File.exist?(CREDENTIALS_PATH)
      Rails.logger.error "Cannot find credentials file at: #{CREDENTIALS_PATH}"
      raise 'Missing Google Credentials File'
    end

    Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: StringIO.new(File.read(CREDENTIALS_PATH)),
      scope: SCOPE
    )
  end

  def ensure_utf8(str)
    return nil if str.nil?

    str.to_s.force_encoding('UTF-8').scrub
  end
end
