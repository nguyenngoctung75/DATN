class Tasks::RedmineIssuesController < ApplicationController
  before_action :set_project
  before_action :authorize_read_project, only: %i[index projects]
  before_action :authorize_manage_project, only: %i[import_one import_url import_selected]

  # GET /projects/:project_id/redmine_issues
  def index
    issues_url = params[:issues_url].presence || "#{RedmineService::BASE_URL}/issues.json"
    redmine_project_input = params[:redmine_project_id].to_s.strip.presence
    redmine_project_id = RedmineService.resolve_project_id(redmine_project_input) if redmine_project_input
    if redmine_project_input.present? && redmine_project_id.blank?
      render json: {
        issues: [], total_count: 0,
        errors: [ 'Redmine project not found with the provided ID or identifier.' ]
      }, status: :unprocessable_entity
      return
    end
    start_date, end_date = bulk_list_date_range

    list_service = RedmineBulkListService.new(@project.id, issues_url: issues_url)
    issues = list_service.list(
      redmine_project_id: redmine_project_id,
      created_on_from: start_date,
      created_on_to: end_date
    )

    render json: {
      issues: issues,
      total_count: issues.size,
      errors: list_service.errors
    }, status: list_service.errors.any? ? :unprocessable_entity : :ok
  end

  # GET /projects/:project_id/redmine_issues/projects
  def projects
    list = Rails.cache.fetch('redmine_projects_list', expires_in: 10.minutes) do
      RedmineService.get_projects_list
    end
    render json: { projects: list }
  end

  # POST /projects/:project_id/redmine_issues/import_one
  def import_one
    issue_id = params[:issue_id]

    if issue_id.blank?
      handle_missing_issue_id
      return
    end

    run = @project.import_runs.create!(
      import_type: 'redmine_url',
      status: 'pending',
      triggered_by: current_user,
      params: { 'issue_id' => issue_id }
    )
    RedmineImportJob.perform_later(run.id)

    respond_to do |format|
      format.html do
        redirect_to import_run_path(run),
                    notice: "Import from Redmine queued. Issue ##{issue_id} is being imported."
      end
      format.json { render json: { import_run_id: run.id }, status: :accepted }
    end
  end

  # POST /projects/:project_id/redmine_issues/import_url
  def import_url
    issues_url = params[:issues_url].presence || "#{RedmineService::BASE_URL}/issues.json"
    issue_ids = params[:issue_ids].present? ? params[:issue_ids].reject(&:blank?) : nil

    run = enqueue_redmine_bulk_import(issues_url: issues_url, issue_ids: issue_ids)
    redirect_to_import_run(run, 'Redmine bulk import started.')
  end

  # POST /projects/:project_id/redmine_issues/import_selected
  def import_selected
    issue_ids = params[:issue_ids].present? ? params[:issue_ids].reject(&:blank?) : nil

    if issue_ids.blank?
      respond_to do |format|
        format.html { redirect_to @project, alert: 'Please select at least one task to import.' }
        format.json { render json: { error: 'issue_ids is required' }, status: :unprocessable_entity }
      end
      return
    end

    run = enqueue_redmine_bulk_import(issue_ids: issue_ids)
    redirect_to_import_run(run, "Importing #{issue_ids.size} selected issue(s) in background.")
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def authorize_read_project
    authorize! :read, @project
  end

  def authorize_manage_project
    authorize! :manage, @project
  end

  def enqueue_redmine_bulk_import(issues_url: nil, issue_ids: nil)
    run = ImportRun.create!(
      project: @project,
      triggered_by: current_user,
      import_type: 'redmine_bulk',
      status: 'pending',
      params: {
        'issues_url' => issues_url,
        'issue_ids' => Array(issue_ids).reject(&:blank?)
      }
    )
    RedmineBulkImportJob.perform_later(run.id)
    run
  end

  def redirect_to_import_run(run, default_notice)
    respond_to do |format|
      format.html { redirect_to import_run_path(run), notice: default_notice }
      format.json { render json: { import_run_id: run.id, status: run.status }, status: :accepted }
    end
  end

  def bulk_list_date_range
    preset = params[:date_preset].to_s
    start_param = params[:start_date].to_s
    end_param = params[:end_date].to_s

    if start_param.present? && end_param.present?
      begin
        [ Date.parse(start_param), Date.parse(end_param) ]
      rescue ArgumentError
        [ nil, nil ]
      end
    else
      r = DateRangePreset.resolve(DateRangePreset.key?(preset) ? preset : 'last_30_days')
      [ r.begin, r.end ]
    end
  end

  def handle_missing_issue_id
    respond_to do |format|
      format.html { redirect_to @project, alert: 'Please provide Issue ID from Redmine.' }
      format.json { render json: { error: 'Issue ID is required' }, status: :unprocessable_entity }
    end
  end
end
