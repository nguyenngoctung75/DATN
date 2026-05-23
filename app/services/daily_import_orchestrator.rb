class DailyImportOrchestrator
  attr_reader :imported_count, :errors

  def initialize(project)
    @project = project
    @imported_count = 0
    @errors = []
    @run = nil
    @lines = []
  end

  def run
    @run = @project.daily_import_runs.create!(status: 'running', started_at: Time.current)
    success, importer = run_import
    finalize(success, importer)
    self
  rescue StandardError => e
    handle_error(e)
    self
  end

  private

  def run_import
    today = Date.current
    base = RedmineService::BASE_URL.sub(/\/*\z/, '')
    full_url = "#{base}#{build_issues_path(today)}"
    log "Import Redmine #{@project.redmine_project_id} -> #{@project.name} for #{today}"

    importer = RedmineBulkImportService.new(@project.id, issues_url: full_url)
    success = importer.import { |count| log "Found #{count} tasks matching '4. Testing'." }
    [ success, importer ]
  end

  def build_issues_path(today)
    RedmineService.build_issues_url(
      RedmineService::BASE_URL,
      project_id: @project.redmine_project_id,
      created_on_from: today,
      created_on_to: today
    )
  end

  def finalize(success, importer)
    if success
      importer.imported_tasks.count == 0 ? finish_skipped(importer) : finish_success(importer)
    else
      finish_failed(importer)
      notify(success: false, error: importer.errors.join(', '))
      @errors = importer.errors.dup
    end
  end

  def finish_skipped(importer)
    log "#{@project.name} — Không có task mới (tìm thấy: #{importer.found_count}, đã có: #{importer.skipped_count})"
    @run.update!(
      status: 'skipped', finished_at: Time.current,
      imported_count: 0, skipped_count: importer.skipped_count,
      log_output: @lines.join("\n")
    )
    notify_no_new_tasks(importer)
  end

  def finish_success(importer)
    @imported_count = importer.imported_tasks.count
    log "#{@project.name} — Imported: #{@imported_count}, Skipped: #{importer.skipped_count}"
    @run.update!(
      status: 'success', finished_at: Time.current,
      imported_count: @imported_count, skipped_count: importer.skipped_count,
      log_output: @lines.join("\n")
    )
    notify(success: true, imported: @imported_count, skipped: importer.skipped_count)
  end

  def finish_failed(importer)
    err = importer.errors.join(', ')
    log "FAILED — #{err}"
    @run.update!(
      status: 'failed', finished_at: Time.current,
      imported_count: importer.imported_tasks.count, skipped_count: importer.skipped_count,
      error_message: err, log_output: @lines.join("\n")
    )
  end

  def handle_error(error)
    log "Error: #{error.message}"
    @errors << error.message
    Rails.logger.error "DailyImportOrchestrator: #{error.message}"
    return unless @run

    @run.update!(
      status: 'failed', finished_at: Time.current,
      error_message: error.message, log_output: @lines.join("\n")
    )
    notify(success: false, error: error.message)
  end

  def notify(success:, imported: nil, skipped: nil, error: nil)
    message = success ? "Imported #{imported}, skipped #{skipped} tasks." : "Failed: #{error.to_s.truncate(120)}"
    Notify.cronjob(
      title: "Daily Import: #{@project.name}",
      message: message,
      link: "/projects/#{@project.id}/daily_import_runs/#{@run.id}"
    )
  end

  def notify_no_new_tasks(importer)
    message = if importer.found_count == 0
      'Cronjob kiểm tra không thấy task mới từ Redmine — không chạy import.'
    else
      "Cronjob kiểm tra: #{importer.found_count} task trên Redmine đã được import trước đó — không có task mới."
    end
    Notify.cronjob(
      title: "Daily Import: #{@project.name}",
      message: message,
      link: "/projects/#{@project.id}/daily_import_runs/#{@run.id}"
    )
  end

  def log(message)
    @lines << "[#{Time.current.strftime('%H:%M:%S')}] #{message}"
    Rails.logger.info "DailyImportOrchestrator: #{@lines.last}"
  end
end
