class TestCaseImport::RowProcessor
  attr_reader :errors, :imported_count, :skipped_count, :task_counts, :last_function_name

  def initialize(task, is_single_sheet:)
    @task = task
    @is_single_sheet = is_single_sheet
    @last_function_name = nil
    @errors = []
    @imported_count = 0
    @skipped_count = 0
    @task_counts = Hash.new(0)
  end

  def process(row, column_mapping, sheet_name, row_number)
    mapper = TestCaseImport::RowMapper.new(row, column_mapping)
    case_data = mapper.case_data

    if case_data[:function].present?
      @last_function_name = case_data[:function]
    elsif @last_function_name.present?
      case_data[:function] = @last_function_name
    end

    title = case_data[:function].presence || case_data[:test_case_title].presence || case_data[:test_id]
    return skip_row(row_number) if title.blank?

    target = find_target_task(sheet_name)
    row_desc = "Imported from sheet: #{ensure_utf8(sheet_name)}, row: #{row_number}"
    test_case = target.test_cases.find_or_initialize_by(description: row_desc)
    test_case.title = title
    test_case.assign_attributes(mapper.attributes(sheet_name, row_number))

    if test_case.save
      test_case.test_steps.destroy_all
      test_case.test_results.destroy_all
      create_test_step(test_case, case_data[:action], case_data[:expected_result])
      TestCaseImport::DeviceResultBuilder.new(test_case, mapper.device_results).build
      @imported_count += 1
      @task_counts[target] += 1
    else
      @errors << "Cannot save test case at row #{row_number}: #{ensure_utf8(test_case.errors.full_messages.join(', '))}"
      @skipped_count += 1
    end
  end

  private

  def find_target_task(sheet_name)
    return @task if sheet_name.blank? || @is_single_sheet || name_match?(@task.title, sheet_name)

    matching_subtask = @task.subtasks.find { |s| name_match?(s.title, sheet_name) }
    return matching_subtask if matching_subtask

    new_subtask = @task.subtasks.find_or_initialize_by(title: ensure_utf8(sheet_name))
    if new_subtask.new_record?
      new_subtask.assign_attributes(
        project_id: @task.project_id,
        description: "Subtask automatic created from sheet: #{ensure_utf8(sheet_name)}",
        status: @task.status,
        start_date: @task.start_date,
        due_date: @task.due_date,
        created_by_name: @task.created_by_name
      )
      new_subtask.save!
      Rails.logger.info "Created new subtask '#{sheet_name}' from sheet"
    end
    new_subtask
  end

  def create_test_step(test_case, action, expected_result)
    step_number = test_case.test_steps.count + 1
    test_step = test_case.test_steps.create!(step_number: step_number, description: "Step #{step_number}")
    create_step_contents(test_step, action, 'action') if action.present?
    create_step_contents(test_step, expected_result, 'expectation') if expected_result.present?
  end

  def create_step_contents(test_step, content, category)
    content.split("\n").reject(&:blank?).each_with_index do |line, index|
      test_step.test_step_contents.create!(
        content_type: 'text',
        content_value: ensure_utf8(line).strip,
        content_category: category,
        display_order: index
      )
    end
  end

  def skip_row(row_number)
    Rails.logger.warn "Skipping row #{row_number}: No test case title"
    @skipped_count += 1
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
