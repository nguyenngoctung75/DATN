class SpreadsheetTablePresenter
  RowInfo = Struct.new(:kind, :test_case, :row_info, :group_description, keyword_init: true)

  def initialize(test_cases)
    @test_cases = test_cases.to_a
  end

  def rows
    return [] if @test_cases.empty?

    metadata = build_row_metadata
    result = []
    prev_group = nil

    @test_cases.each_with_index do |tc, i|
      current_group = tc.group_description.to_s.strip
      if current_group.present? && current_group != prev_group
        result << RowInfo.new(kind: :group_header, test_case: tc, group_description: current_group)
      end
      result << RowInfo.new(kind: :test_case, test_case: tc, row_info: metadata[i])
      prev_group = current_group
    end

    result
  end

  private

  def build_row_metadata
    metadata = {}
    current_title = nil
    row_start_index = 0
    total_tr_span = 0

    @test_cases.each_with_index do |tc, i|
      title = tc.title.to_s.strip

      if title != current_title
        metadata[row_start_index] = { rowspan: total_tr_span } if i > 0
        current_title = title
        row_start_index = i
        total_tr_span = 0
      end

      total_tr_span += 1

      if i == @test_cases.size - 1
        metadata[row_start_index] = { rowspan: total_tr_span }
        ((row_start_index + 1)..i).each { |k| metadata[k] = { hide: true } }
      elsif @test_cases[i + 1]&.title.to_s.strip != current_title
        ((row_start_index + 1)..i).each { |k| metadata[k] = { hide: true } }
      end
    end

    metadata
  end
end
