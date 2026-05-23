# frozen_string_literal: true

module TestCaseClone
  # Decides whether to clone synchronously (small batches) or enqueue a background
  # job via the existing ImportRun pattern (large batches).
  class Dispatcher
    SYNC_THRESHOLD = 50

    DispatchError = Class.new(StandardError)

    def initialize(source_task:, source_ids:, destination_task_id:, options:, user:)
      @source_task = source_task
      @source_ids = Array(source_ids).compact_blank.map(&:to_i)
      @destination_task_id = destination_task_id.to_i
      @options = (options || {}).to_h.symbolize_keys
      @user = user
    end

    def call
      destination = find_destination_task
      validate_same_project!(destination)

      sources = source_relation
      return Result.failure(error: 'No test cases selected to clone.') if sources.empty?

      if sources.size <= SYNC_THRESHOLD
        run_sync(sources, destination)
      else
        enqueue_async(sources, destination)
      end
    rescue DispatchError => e
      Result.failure(error: e.message)
    end

    private

    def find_destination_task
      task = Task.find_by(id: @destination_task_id)
      raise DispatchError, 'Destination task not found.' unless task
      raise DispatchError, 'Destination task is archived.' if task.deleted_at.present?

      task
    end

    def validate_same_project!(destination)
      return if destination.project_id == @source_task.project_id

      raise DispatchError, 'Cross-project cloning is not supported yet.'
    end

    def source_relation
      base = @source_task.test_cases.active
      @source_ids.any? ? base.where(id: @source_ids) : base
    end

    def run_sync(sources, destination)
      CloneService.new(
        source_test_cases: sources,
        destination_task: destination,
        options: @options,
        user: @user
      ).call
    end

    def enqueue_async(sources, destination)
      run = ImportRun.create!(
        project: destination.project,
        triggered_by: @user,
        import_type: 'clone_tc',
        status: 'pending',
        total_count: sources.size,
        params: {
          'source_task_id' => @source_task.id,
          'source_ids' => sources.pluck(:id),
          'destination_task_id' => destination.id,
          'options' => @options.stringify_keys
        }
      )
      TestCaseCloneJob.perform_later(run.id)
      Result.async(import_run: run)
    end
  end
end
