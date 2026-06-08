class RedmineBulkImportJob < ApplicationJob
  queue_as :default

  def perform(import_run_id)
    run = ImportRun.find(import_run_id)
    return if run.finished?

    issues_url = run.params['issues_url'].presence || "#{RedmineService::BASE_URL}/issues.json"
    issue_ids = run.params['issue_ids']

    run.update!(status: 'running', started_at: Time.current)
    run.broadcast_progress(event: 'import_started')

    service = RedmineBulkImportService.new(run.project_id, issues_url: issues_url, import_run: run)
    success = if issue_ids.present?
                service.import_by_issue_ids(issue_ids)
    else
                service.import_all
    end

    if success && service.errors.empty?
      finalize_success(run, service)
    elsif service.imported_tasks.any?
      finalize_partial(run, service)
    else
      finalize_failed(run, service)
    end
    notify_completion(run, service)
  rescue StandardError => e
    fail_with_exception(run, e)
    notify_exception(run, e)
    raise
  end

  private

  def finalize_success(run, service)
    run.update!(
      status: 'success',
      finished_at: Time.current,
      imported_count: service.imported_tasks.size,
      skipped_count: service.skipped_count.to_i,
      total_count: [ run.total_count, service.found_count.to_i ].max
    )
    run.broadcast_progress(event: 'import_complete')
  end

  def finalize_partial(run, service)
    run.update!(
      status: 'success',
      finished_at: Time.current,
      imported_count: service.imported_tasks.size,
      skipped_count: service.skipped_count.to_i,
      error_message: service.errors.join("\n").truncate(2000)
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
        title: 'Bulk Redmine import failed',
        message: service.errors.first.to_s.truncate(160),
        link: Rails.application.routes.url_helpers.import_run_path(run.id)
      )
    else
      Notify.info(
        title: 'Bulk Redmine import done',
        message: "Imported #{service.imported_tasks.size} tasks (skipped #{service.skipped_count.to_i})",
        link: Rails.application.routes.url_helpers.project_path(run.project_id)
      )
    end
  end

  def notify_exception(run, exception)
    Notify.warning(
      title: 'Bulk Redmine import error',
      message: exception.message.to_s.truncate(160),
      link: Rails.application.routes.url_helpers.import_run_path(run.id)
    )
  end
end
