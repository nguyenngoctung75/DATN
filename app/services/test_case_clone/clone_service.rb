# frozen_string_literal: true

module TestCaseClone
  # Deep-copies TestCase records (with TestStep + TestStepContent) into a destination Task.
  # Does NOT copy TestResult (status reset) or Bug (run-time data stays with origin).
  #
  # Usage:
  #   TestCaseClone::CloneService.new(
  #     source_test_cases: relation,
  #     destination_task: dest_task,
  #     options: { append_copy_suffix: false, place_at_top: false },
  #     user: current_user,
  #     import_run: optional_run
  #   ).call
  class CloneService
    def initialize(source_test_cases:, destination_task:, options: {}, user:, import_run: nil)
      @source_relation = source_test_cases
      @dest = destination_task
      @options = (options || {}).symbolize_keys
      @user = user
      @run = import_run
    end

    def call
      sources = @source_relation.includes(test_steps: :test_step_contents).to_a
      return Result.success(count: 0, ids: [], import_run: @run) if sources.empty?

      cloned_ids = []
      ActiveRecord::Base.transaction do
        @run&.update!(total_count: sources.size) if @run && @run.total_count.to_i.zero?

        if @options[:place_at_top]
          TestCase.insert_at_position!(@dest, 1)
          base_pos = 0
        else
          base_pos = @dest.test_cases.maximum(:position) || 0
        end

        sources.each_with_index do |src, idx|
          new_tc = clone_one!(src, position: base_pos + idx + 1)
          cloned_ids << new_tc.id
          @run&.increment_progress!(by: 1)
        end

        Task.where(id: @dest.id).update_all(
          number_of_test_cases: TestCase.active.where(task_id: @dest.id).count
        )
      end

      Result.success(count: cloned_ids.size, ids: cloned_ids, import_run: @run)
    rescue StandardError => e
      Rails.logger.error("[TestCaseClone] failed: #{e.class}: #{e.message}")
      Result.failure(error: e.message, import_run: @run)
    end

    private

    def clone_one!(src, position:)
      new_tc = @dest.test_cases.new(
        title: title_for(src),
        description: src.description,
        test_type: src.test_type,
        target: src.target,
        note: src.note,
        position: position,
        created_by: @user
      )
      new_tc.skip_title_sync = true
      new_tc.save!
      clone_steps(src, new_tc)
      new_tc
    end

    def clone_steps(src, new_tc)
      src.test_steps.each do |step|
        new_step = new_tc.test_steps.create!(
          step_number: step.step_number,
          description: step.description,
          display_order: step.display_order
        )
        clone_step_contents(step, new_step)
      end
    end

    def clone_step_contents(step, new_step)
      rows = step.test_step_contents.map do |c|
        {
          step_id: new_step.id,
          content_type: c.content_type,
          content_value: c.content_value,
          content_category: c.content_category,
          display_order: c.display_order,
          is_expected: c.is_expected,
          created_at: Time.current,
          updated_at: Time.current
        }
      end
      TestStepContent.insert_all(rows) if rows.any?
    end

    def title_for(src)
      same_task = src.task_id == @dest.id
      return "#{src.title} (copy)" if same_task || @options[:append_copy_suffix]

      src.title
    end
  end
end
