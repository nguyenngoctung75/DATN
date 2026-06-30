class BugsController < ApplicationController
  before_action :set_project
  before_action :set_task
  before_action :set_bug, only: %i[show edit update destroy restore soft_delete cell_history revert]

  BUG_HISTORY_FIELDS = %w[content application category bug_type priority dev_id tester_id status image_video_url
notes].freeze
  before_action :require_project_membership!
  authorize_resource

  def index
    @page = (params[:page] || 1).to_i
    @per_page = 20

    @all_bugs = @task.bugs.active.order(id: :asc)
    @all_bugs = @all_bugs.by_category(params[:category]) if params[:category].present?
    @all_bugs = @all_bugs.by_priority(params[:priority]) if params[:priority].present?

    @total_bugs = @all_bugs.count
    @total_pages = (@total_bugs.to_f / @per_page).ceil

    offset = (@page - 1) * @per_page
    @bugs = @all_bugs.offset(offset).limit(@per_page)

    @archived_bugs = @task.bugs.deleted.order(deleted_at: :desc)

    @users = User.active.order(:name)
  end

  def show; end

  def new
    @bug = @task.bugs.build
  end

  def create
    @bug = @task.bugs.build(bug_params)
    if @bug.save
      respond_to do |format|
        format.html {
 redirect_to project_task_bugs_path(@project, @task), notice: 'Bug has been created successfully.' }
        format.turbo_stream do
          @total_bugs = @task.bugs.active.count
          bug_index = @task.bugs.active.order(id: :asc).where('id <= ?', @bug.id).count - 1
          render turbo_stream: turbo_stream.append('bugs-spreadsheet-list',
                                                   partial: 'bugs/spreadsheet_row',
                                                   locals: { bug: @bug, index: [ bug_index, 0 ].max + 1 })
        end
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream do
          msg = "Failed to create bug: #{@bug.errors.full_messages.join(', ')}"
          render turbo_stream: turbo_stream.prepend('flash-messages',
                                                    partial: 'shared/flash',
                                                    locals: { flash: { alert: msg } })
        end
      end
    end
  end

  def edit; end

  def update
    if @bug.update(bug_params)
      respond_to { |format| respond_bug_update_success(format) }
    else
      respond_to { |format| respond_bug_update_failure(format) }
    end
  end

  def destroy
    @bug.soft_delete!
    redirect_to project_task_bugs_path(@project, @task), notice: 'Bug has been deleted successfully.'
  end

  def soft_delete
    @bug.soft_delete!
    respond_to do |format|
      format.html { redirect_to project_task_bugs_path(@project, @task), notice: 'Bug archived successfully.' }
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("bug-row-#{@bug.id}")
      end
    end
  end

  def restore
    @bug.restore!
    redirect_to project_task_bugs_path(@project, @task), notice: 'Bug has been restored successfully.'
  end

  def cell_history
    field = params[:field].to_s
    return render json: { error: 'Invalid field' },
status: :unprocessable_entity unless BUG_HISTORY_FIELDS.include?(field)

    logs = ActivityLog.where(trackable: @bug).includes(:user).order(created_at: :desc).to_a
                      .select { |l| l.metadata.is_a?(Hash) && l.metadata.key?(field) }
    render json: CellHistorySerializer.call(logs, field)
  end

  def revert
    log = ActivityLog.where(trackable: @bug).find(params[:log_id])
    result = RecordRevertService.new(record: @bug, activity_log: log, field: params[:field]).call
    if result.success?
      @bug.reload
      @bug_index = @task.bugs.active.order(id: :asc).where('id <= ?', @bug.id).count
      flash.now[:notice] = "Reverted #{params[:field]} to previous value"
      respond_to do |format|
        format.turbo_stream { render :revert }
        format.html { redirect_to project_task_bugs_path(@project, @task), notice: flash.now[:notice] }
      end
    else
      render json: { error: result.error_message }, status: :unprocessable_entity
    end
  end

  def import_from_sheet
    if @task.bug_link.blank?
      redirect_to project_task_bugs_path(@project, @task), alert: 'Task has no bug link to import from.'
      return
    end

    spreadsheet_id = extract_spreadsheet_id(@task.bug_link)
    run = @project.import_runs.create!(
      import_type: 'manual_bug',
      status: 'pending',
      triggered_by: current_user,
      params: {
        'task_id' => @task.id,
        'spreadsheet_id' => spreadsheet_id,
        'wipe_existing' => params[:wipe_existing] == '1'
      }
    )
    BugImportJob.perform_later(run.id)

    redirect_to import_run_path(run), notice: 'Bug import queued. Running in background.'
  end

  private

  def respond_bug_update_success(format)
    format.html do
      redirect_to project_task_bug_path(@project, @task, @bug), notice: 'Bug has been updated successfully.'
    end
    format.turbo_stream do
      bug_index = @task.bugs.active.order(id: :asc).where('id <= ?', @bug.id).count - 1
      render turbo_stream: turbo_stream.replace("bug-row-#{@bug.id}",
                                                partial: 'bugs/spreadsheet_row',
                                                locals: { bug: @bug, index: [ bug_index, 0 ].max + 1 })
    end
    format.json do
      render json: @bug.as_json.merge(
        formatted_value: helpers.format_content_with_media_links(@bug.send(bug_params.keys.first.to_s) || '')
      )
    end
  end

  def respond_bug_update_failure(format)
    format.html { render :edit, status: :unprocessable_entity }
    format.turbo_stream do
      msg = "Failed to update bug: #{@bug.errors.full_messages.join(', ')}"
      render turbo_stream: turbo_stream.prepend('flash-messages',
                                                partial: 'shared/flash',
                                                locals: { flash: { alert: msg } })
    end
    format.json { render json: { errors: @bug.errors.full_messages }, status: :unprocessable_entity }
  end

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_task
    @task = @project.tasks.find(params[:task_id])
  end

  def set_bug
    @bug = Bug.unscoped.find_by!(id: params[:id], task_id: @task.id)
  end

  def bug_params
    params.require(:bug).permit(:title, :content, :application, :category, :priority, :status, :dev_id, :tester_id,
                                :image_video_url, :notes, :bug_type)
  end

  def extract_spreadsheet_id(url)
    match = url.match(%r{/spreadsheets/d/([a-zA-Z0-9_-]+)})
    match ? match[1] : url
  end
end
