module TestCaseImport
  class RowMapper
    def initialize(row, mapping)
      @row = row
      @mapping = mapping
    end

    def case_data
      @case_data ||= {
        test_id: get_cell(mapping[:id]),
        test_type: get_cell(mapping[:test_type]),
        function: get_cell(mapping[:function]),
        test_case_title: get_cell(mapping[:test_case]),
        action: get_cell(mapping[:action]),
        expected_result: get_cell(mapping[:expected_result]),
        target: get_cell(mapping[:target]),
        ac_url: get_cell(mapping[:acceptance_criteria]),
        us_url: get_cell(mapping[:user_story])
      }
    end

    def device_results
      @device_results ||= begin
        cols = mapping[:device_columns]
        return [] if cols.blank?

        cols.each_with_object([]) do |col, results|
          value = get_cell(col[:index])
          next if value.blank?

          results << { device: ensure_utf8(col[:name]), status: normalize_status(value), raw_value: value }
        end
      end
    end

    def attributes(sheet_name, row_number)
      data = case_data
      {
        test_type: normalize_test_type(data[:test_type]),
        target: normalize_target(data[:target]),
        description: "Imported from sheet: #{ensure_utf8(sheet_name)}, row: #{row_number}"
      }
    end

    private

    attr_reader :mapping

    def get_cell(index)
      return nil if index.nil? || @row.nil? || @row[index].nil?

      ensure_utf8(@row[index]).strip
    end

    def normalize_test_type(test_type)
      return 'feature' if test_type.blank?

      case ensure_utf8(test_type).downcase
      when 'ui', 'ユーザーインターフェース', 'giao diện' then 'ui'
      when 'data', 'データ', 'dữ liệu' then 'data'
      else 'feature'
      end
    end

    def normalize_target(target)
      return 'pc_sp_app' if target.blank?

      normalized = ensure_utf8(target).downcase.gsub(/[・、\s]/, '_')
      if normalized.include?('pc') && normalized.include?('sp')
        normalized.include?('app') ? 'pc_sp_app' : 'pc_sp'
      elsif %w[app pc sp].include?(normalized)
        normalized
      else
        'pc_sp_app'
      end
    end

    def normalize_status(value)
      return 'not_run' if value.blank?

      case ensure_utf8(value).downcase
      when /pass/, /ok/, /success/, /成功/ then 'pass'
      when /fail/, /error/, /ng/, /失敗/ then 'fail'
      when /not.*run/, /未実施/, /skip/, /pending/ then 'not_run'
      else 'unknown'
      end
    end

    def ensure_utf8(str)
      return '' if str.nil?

      str = str.to_s
      str = str.dup if str.frozen?
      str.force_encoding('UTF-8').scrub
    end
  end
end
