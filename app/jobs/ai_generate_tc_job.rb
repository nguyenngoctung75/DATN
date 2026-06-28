# frozen_string_literal: true

class AiGenerateTcJob < ApplicationJob
  queue_as :default

  def perform(import_run_id)
    run = ImportRun.find(import_run_id)
    return if run.finished?

    task = run.project.tasks.find(run.params['task_id'])
    run.update!(status: 'running', started_at: Time.current)
    run.broadcast_progress(event: 'import_started')

    service = AiTestCaseGenerationService.new(
      task,
      description: run.params['description'],
      github_url: run.params['github_url'],
      count: run.params['count'],
      user: run.triggered_by
    )
    handle_success(run, service.generate!, task)
  rescue StandardError => e
    handle_exception(run, e)
    raise
  end

  private

  def handle_success(run, result, task)
    run.update!(
      status: 'success',
      finished_at: Time.current,
      imported_count: result.imported_count,
      skipped_count: result.skipped_count
    )
    run.broadcast_progress(event: 'import_complete')
    Notify.info(
      title: "AI test cases generated: #{task.title.truncate(60)}",
      message: "Generated #{result.imported_count}, skipped #{result.skipped_count}. Refresh the task to view them.",
      link: Rails.application.routes.url_helpers.project_task_path(run.project_id, task.id)
    )
  end

  def handle_exception(run, error)
    if run
      run.update!(status: 'failed', finished_at: Time.current, error_message: error.message.truncate(2000))
      run.broadcast_progress(event: 'import_failed')
    end
    Notify.warning(
      title: 'AI test case generation failed',
      message: error.message.truncate(160),
      link: Rails.application.routes.url_helpers.import_run_path(run&.id)
    )
  end
end
