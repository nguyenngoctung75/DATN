module BugImport
  class RowParser
    def parse_header(header_row)
      mapping = {}
      header_row.each_with_index do |col_name, index|
        next if col_name.blank?

        name = ensure_utf8(col_name).downcase
        case name
        when /^no$/, /^stt$/ then mapping[:no] = index
        when /^content$/, /^mô tả$/, /^bug content$/ then mapping[:content] = index
        when /^application$/, /^app$/ then mapping[:application] = index
        when /^category/, /^loại/, /^biến thể$/ then mapping[:category] = index
        when /^priority$/, /^mức độ ưu tiên$/, /^độ ưu tiên$/ then mapping[:priority] = index
        when /^dev$/ then mapping[:dev] = index
        when /^test$/, /^tester$/ then mapping[:test] = index
        when /^status$/, /^trạng thái$/ then mapping[:status] = index
        when /^image/, /^video/, /^gyazo/, /^link.*ảnh/ then mapping[:media] = index
        when /^bug.?type$/, /^loại.?bug$/ then mapping[:bug_type] = index
        end
      end
      mapping
    end

    def parse_row(row, mapping)
      {
        content: cell(row, mapping[:content]),
        application: cell(row, mapping[:application]),
        category: cell(row, mapping[:category]),
        priority: cell(row, mapping[:priority]),
        status: cell(row, mapping[:status]),
        bug_type: cell(row, mapping[:bug_type]),
        media: cell(row, mapping[:media]),
        dev: cell(row, mapping[:dev]),
        tester: cell(row, mapping[:test])
      }
    end

    private

    def cell(row, index)
      return nil if index.nil? || row[index].nil?

      ensure_utf8(row[index].to_s).strip
    end

    def ensure_utf8(str)
      str = str.to_s
      str = str.dup if str.frozen?
      str.force_encoding('UTF-8').scrub
    end
  end
end
