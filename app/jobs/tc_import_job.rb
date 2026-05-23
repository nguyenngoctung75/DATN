class TcImportJob < ApplicationJob
  queue_as :default

  def perform(import_run_id)
    run = ImportRun.find(import_run_id)
    return if run.finished?

    task = run.project.tasks.find(run.params['task_id'])
    spreadsheet_id = run.params['spreadsheet_id']
    wipe_existing = run.params['wipe_existing']
    run.update!(status: 'running', started_at: Time.current)
    run.broadcast_progress(event: 'import_started')
    service = TestCaseImportService.new(task, spreadsheet_id, wipe_existing: wipe_existing)
    if service.import
      handle_success(run, service, task)
    else
      handle_failure(run, service)
    end
  rescue StandardError => e
    handle_exception(run, e)
    raise
  end

  private

  def handle_success(run, service, task)
    run.update!(
      status: 'success',
      finished_at: Time.current,
      imported_count: service.imported_count,
      skipped_count: service.skipped_count
    )
    run.broadcast_progress(event: 'import_complete')
    Notify.info(
      title: "TC import done: #{task.title.truncate(60)}",
      message: "Imported #{service.imported_count}, skipped #{service.skipped_count}",
      link: Rails.application.routes.url_helpers.project_task_path(run.project_id, task.id)
    )
  end

  def handle_failure(run, service)
    error_msg = service.errors.join(', ').truncate(2000)
    run.update!(status: 'failed', finished_at: Time.current, error_message: error_msg)
    run.broadcast_progress(event: 'import_failed')
    Notify.warning(
      title: 'TC import failed',
      message: error_msg.truncate(160),
      link: Rails.application.routes.url_helpers.import_run_path(run.id)
    )
  end

  def handle_exception(run, e)
    if run
      run.update!(status: 'failed', finished_at: Time.current, error_message: e.message.truncate(2000))
      run.broadcast_progress(event: 'import_failed')
    end
    Notify.warning(
      title: 'TC import error',
      message: e.message.truncate(160),
      link: Rails.application.routes.url_helpers.import_run_path(run&.id)
    )
  end
end
