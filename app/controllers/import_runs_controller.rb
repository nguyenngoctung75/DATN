class ImportRunsController < ApplicationController
  before_action :set_import_run
  before_action :authorize_import_run

  def show
    respond_to do |format|
      format.html
      format.json { render json: status_payload }
    end
  end

  def status
    render json: status_payload
  end

  private

  def set_import_run
    @import_run = ImportRun.find(params[:id])
  end

  def authorize_import_run
    authorize! :read, @import_run
  end

  def status_payload
    {
      id: @import_run.id,
      status: @import_run.status,
      import_type: @import_run.import_type,
      processed_count: @import_run.processed_count,
      total_count: @import_run.total_count,
      imported_count: @import_run.imported_count,
      skipped_count: @import_run.skipped_count,
      progress_percent: @import_run.progress_percent,
      error_message: @import_run.error_message,
      started_at: @import_run.started_at&.iso8601,
      finished_at: @import_run.finished_at&.iso8601
    }
  end
end
