class ManualImportJob < ApplicationJob
  queue_as :default

  def perform(import_run_id)
    run = ImportRun.find(import_run_id)
    return if run.finished?

    task = run.project.tasks.find(run.params['task_id'])

    run.update!(status: 'running', started_at: Time.current)
    run.broadcast_progress(event: 'import_started')

    orchestrator = ManualImportOrchestrator.new(task, import_run: run).run
    finalize_success(run, orchestrator)
    notify_done(run, task, orchestrator)
  rescue StandardError => e
    finalize_failed(run, e)
    notify_failed(run, e)
    raise
  end

  private

  def finalize_success(run, orchestrator)
    total_imported = orchestrator.tc_count.to_i + orchestrator.bug_count.to_i
    run.update!(
      status: 'success',
      finished_at: Time.current,
      imported_count: total_imported,
      total_count: [ run.total_count, run.processed_count ].max
    )
    run.broadcast_progress(event: 'import_complete')
  end

  def finalize_failed(run, exception)
    run.update!(
      status: 'failed',
      finished_at: Time.current,
      error_message: exception.message.to_s.truncate(2000)
    )
    run.broadcast_progress(event: 'import_failed')
  end

  def notify_done(run, task, orchestrator)
    parts = []
    parts << "#{orchestrator.tc_count} test cases" if orchestrator.tc_count.to_i.positive?
    parts << "#{orchestrator.bug_count} bugs" if orchestrator.bug_count.to_i.positive?
    summary = parts.empty? ? 'No new records' : "Imported #{parts.join(' and ')}"

    Notify.info(
      title: "Import done: #{task.title.to_s.truncate(60)}",
      message: summary,
      link: Rails.application.routes.url_helpers.project_task_path(run.project_id, task.id)
    )
  end

  def notify_failed(run, exception)
    Notify.warning(
      title: 'Import failed',
      message: exception.message.to_s.truncate(160),
      link: Rails.application.routes.url_helpers.import_run_path(run.id)
    )
  end
end
