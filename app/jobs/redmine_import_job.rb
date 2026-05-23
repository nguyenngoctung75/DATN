class RedmineImportJob < ApplicationJob
  queue_as :default

  def perform(import_run_id)
    run = ImportRun.find(import_run_id)
    return if run.finished?

    issue_id = run.params['issue_id']

    run.update!(status: 'running', started_at: Time.current)
    run.broadcast_progress(event: 'import_started')

    service = RedmineImportService.new(issue_id, run.project_id)

    if service.import
      finalize_success(run, service)
    else
      finalize_failed(run, service)
    end
    notify_completion(run, service)
  rescue StandardError => e
    fail_with_exception(run, e)
    Notify.warning(
      title: 'Redmine import error',
      message: e.message.to_s.truncate(160),
      link: Rails.application.routes.url_helpers.import_run_path(run.id)
    )
    raise
  end

  private

  def finalize_success(run, service)
    task = service.task
    run.update!(
      status: 'success',
      finished_at: Time.current,
      imported_count: task&.number_of_test_cases.to_i
    )
    run.broadcast_progress(event: 'import_complete')
  end

  def finalize_failed(run, service)
    run.update!(
      status: 'failed',
      finished_at: Time.current,
      error_message: service.errors.join("\n").truncate(2000)
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

  def notify_completion(run, service)
    if run.status == 'failed'
      Notify.warning(
        title: 'Redmine import failed',
        message: service.errors.first.to_s.truncate(160),
        link: Rails.application.routes.url_helpers.import_run_path(run.id)
      )
    else
      Notify.info(
        title: 'Redmine import done',
        message: "Task imported with #{run.imported_count} test cases",
        link: Rails.application.routes.url_helpers.project_path(run.project_id)
      )
    end
  end
end
