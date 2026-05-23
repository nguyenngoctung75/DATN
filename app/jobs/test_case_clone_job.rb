# frozen_string_literal: true

class TestCaseCloneJob < ApplicationJob
  queue_as :default

  def perform(import_run_id)
    run = ImportRun.find(import_run_id)
    return if run.finished?

    run.update!(status: 'running', started_at: Time.current)
    run.broadcast_progress(event: 'import_started')

    params = run.params
    source_task = Task.find(params['source_task_id'])
    destination_task = Task.find(params['destination_task_id'])
    user = run.triggered_by
    Current.user = user if user

    sources = source_task.test_cases.active.where(id: params['source_ids'])

    result = TestCaseClone::CloneService.new(
      source_test_cases: sources,
      destination_task: destination_task,
      options: (params['options'] || {}).to_h,
      user: user,
      import_run: run
    ).call

    if result.success?
      finalize_success(run, result, destination_task)
    else
      finalize_failed(run, result.error)
    end
    notify_completion(run, result, destination_task)
  rescue StandardError => e
    fail_with_exception(run, e)
    notify_exception(run, e)
    raise
  ensure
    Current.user = nil
  end

  private

  def finalize_success(run, result, destination_task)
    run.update!(
      status: 'success',
      finished_at: Time.current,
      imported_count: result.count
    )
    run.broadcast_progress(event: 'import_complete')
  end

  def finalize_failed(run, error_message)
    run.update!(
      status: 'failed',
      finished_at: Time.current,
      error_message: error_message.to_s.truncate(2000)
    )
    run.broadcast_progress(event: 'import_failed')
  end

  def fail_with_exception(run, exception)
    run.update!(
      status: 'failed',
      finished_at: Time.current,
      error_message: exception.message.to_s.truncate(2000)
    )
    run.broadcast_progress(event: 'import_failed')
  end

  def notify_completion(run, result, destination_task)
    if run.status == 'failed'
      Notify.warning(
        title: 'Clone test cases failed',
        message: result.error.to_s.truncate(160),
        link: Rails.application.routes.url_helpers.import_run_path(run.id)
      )
    else
      Notify.info(
        title: 'Test cases cloned',
        message: "Cloned #{result.count} test case(s) into '#{destination_task.title}'",
        link: Rails.application.routes.url_helpers.project_task_path(destination_task.project_id, destination_task.id)
      )
    end
  end

  def notify_exception(run, exception)
    Notify.warning(
      title: 'Clone test cases error',
      message: exception.message.to_s.truncate(160),
      link: Rails.application.routes.url_helpers.import_run_path(run.id)
    )
  end
end
