module TestCaseImport
  # Parses raw sheet data to determine column layout and data boundaries.
  # Handles multi-row headers and device-names rows that precede data.
  class SheetMetadataParser
    def initialize(sheet_data)
      @sheet_data = sheet_data
      @header_index = find_header_row_index
      @start = @header_index ? determine_starting_point : nil
    end

    def valid?
      !@header_index.nil? && !@start.nil?
    end

    def data_rows
      @start&.dig(:data_rows)
    end

    def starting_row_number
      @start&.dig(:starting_row_number)
    end

    def column_mapping
      return nil unless valid?

      parse_header(
        [ @sheet_data[@header_index] ],
        @start[:device_names_row]
      )
    end

    private

    def find_header_row_index
      @sheet_data.first(10).each_with_index do |row, index|
        next if row.nil? || row.empty?

        row_str = row.map { |c| ensure_utf8(c).to_s.downcase }.join(' ')
        return index if header_row?(row_str)
      end
      nil
    end

    def determine_starting_point
      header_row = @sheet_data[@header_index]
      possible_next_row = @sheet_data[@header_index + 1] if @sheet_data.length > @header_index + 1

      if data_row?(possible_next_row, header_row)
        { data_rows: @sheet_data.drop(@header_index + 1), starting_row_number: @header_index + 2,
device_names_row: nil }
      else
        { data_rows: @sheet_data.drop(@header_index + 2), starting_row_number: @header_index + 3,
device_names_row: possible_next_row }
      end
    end

    def header_row?(row_str)
      return false unless row_str.include?('id') || row_str.include?('no')

      [ 'funtion', 'function', 'test case', '項目' ].any? { |k| row_str.include?(k) }
    end

    def data_row?(row, header_row)
      return false if row.nil? || row.empty? || header_row.nil?

      target_col_index = find_target_column_index(header_row)
      return false if target_col_index.nil?

      row_contains_status?(row, target_col_index, header_row.length) || row_contains_identifier?(row)
    end

    def find_target_column_index(header_row)
      header_row.each_with_index do |col_name, index|
        next if col_name.blank?

        return index if ensure_utf8(col_name).downcase.match?(/^target$|^対象$|^đối.*tượng$/)
      end
      nil
    end

    def row_contains_status?(row, target_idx, row_len)
      ((target_idx + 1)...row_len).any? do |idx|
        val = ensure_utf8(row[idx]).downcase
        val.match?(/^(pass|fail|failed|ok|ng|not.*run|skip|pending|block|blocked)$/i) || val.match?(/^tc\d+$/i)
      end
    end

    def row_contains_identifier?(row)
      row.first(4).any? do |val|
        val_norm = ensure_utf8(val).downcase
        val_norm.match?(/^tc\d+$/i) || val_norm.match?(/^\d+$/)
      end
    end

    def parse_header(header_rows, device_names_row = nil)
      header_row = header_rows.last || []
      mapping = {}
      device_columns = []

      header_row.each_with_index do |col_name, index|
        next if col_name.blank?
        break if ensure_utf8(col_name).downcase.match?(/^note$|^備考$|^ghi.*chú$/)

        map_column_header(col_name, index, mapping, device_columns)
      end

      if device_names_row && mapping[:target]
        add_device_row_columns(header_row, device_names_row, mapping[:target], device_columns)
      end

      finalize_mapping(mapping, device_columns)
    end

    def map_column_header(col_name, index, mapping, device_columns)
      name = ensure_utf8(col_name).downcase

      case name
      when /^id$/, /^no$/, /^stt$/, /^順番$/ then mapping[:id] = index
      when /^type$/, /^test.*type$/, /^種別$/ then mapping[:test_type] = index
      when /^function$/, /^funtion$/, /^機能$/, /^chức.*năng$/ then mapping[:function] = index
      when /^test.*case$/, /^test.*item$/, /^項目$/, /^test.*nội.*dung$/ then mapping[:test_case] = index
      when /^action$/, /^操作$/, /^thao.*tác$/, /^step$/, /^test.*step/ then mapping[:action] = index
      when /^expected.*result$/, /^期待.*結果$/, /^kết.*quả.*mong.*đợi$/, /^result$/ then mapping[:expected_result] = index
      when /^target$/, /^対象$/, /^đối.*tượng$/ then mapping[:target] = index
      when /^ac$/, /^acceptance.*criteria$/, /^受入.*基準$/ then mapping[:acceptance_criteria] = index
      when /^us$/, /^user.*story$/, /^ユーザー.*ストーリー$/ then mapping[:user_story] = index
      when /chrome|firefox|safari|android|ios/,
           /^prod(uction)?$/i, /environment|version/
        device_columns << { index: index, name: ensure_utf8(col_name) }
      end
    end

    def add_device_row_columns(header_row, device_row, target_idx, device_columns)
      return if row_contains_status?(device_row, target_idx, header_row.length)

      ((target_idx + 1)...header_row.length).each do |idx|
        header_name = header_row[idx]
        break if ensure_utf8(header_name)&.match?(/^note$/i)

        device_name = device_row[idx]
        device_columns << { index: idx, name: ensure_utf8(device_name) } if device_name.present?
      end
    end

    def finalize_mapping(mapping, device_columns)
      mapping[:device_columns] = device_columns.uniq { |col| col[:index] }
      Rails.logger.info "Parsed device columns: #{mapping[:device_columns].inspect}"
      mapping
    end

    def ensure_utf8(str)
      return '' if str.nil?

      str = str.to_s
      str = str.dup if str.frozen?
      str.force_encoding('UTF-8').scrub
    end
  end
end
