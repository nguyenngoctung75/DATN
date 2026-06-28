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
    return metadata if @test_cases.empty?

    run_start = 0
    prev_group = nil

    @test_cases.each_with_index do |tc, i|
      group = tc.group_description.to_s.strip
      # A group-description header row is injected before this row when its
      # group changes (see #rows). That header is a full-width (colspan) <tr>,
      # so a title-merge rowspan must NOT span across it — break the run here.
      header_before = group.present? && group != prev_group

      if i.positive? && (tc.title.to_s.strip != @test_cases[i - 1].title.to_s.strip || header_before)
        finalize_run(metadata, run_start, i - 1)
        run_start = i
      end

      prev_group = group
    end

    finalize_run(metadata, run_start, @test_cases.size - 1)
    metadata
  end

  def finalize_run(metadata, start_index, end_index)
    span = end_index - start_index + 1
    metadata[start_index] = { rowspan: span }
    ((start_index + 1)..end_index).each { |k| metadata[k] = { hide: true } }
  end
end
