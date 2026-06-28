class ProjectsController < ApplicationController
  before_action :set_project, except: %i[index new create archived]
  before_action :authorize_admin, except: %i[index show archived]
  before_action :authorize_project_read, only: :show

  def index
    projects_per_page = 12 # 12 projects for nice grid layout (3x4 or 4x3)
    page = (params[:page] || 1).to_i

    all_projects = Project.active.order(created_at: :desc)
    all_projects = all_projects.where(id: current_user.accessible_project_ids) unless current_user.admin?
    @total_projects = all_projects.count
    @total_pages = (@total_projects.to_f / projects_per_page).ceil
    @current_page = page

    # Paginate
    offset = (page - 1) * projects_per_page
    @projects = all_projects.limit(projects_per_page).offset(offset)

    respond_to do |format|
      format.html
      format.json { render json: @projects }
    end
  end

  def archived
    projects_per_page = 12
    page = (params[:page] || 1).to_i

    all_archived = Project.deleted.order(deleted_at: :desc)
    all_archived = all_archived.where(id: current_user.accessible_project_ids) unless current_user.admin?
    @total_projects = all_archived.count
    @total_pages = (@total_projects.to_f / projects_per_page).ceil
    @current_page = page

    # Paginate
    offset = (page - 1) * projects_per_page
    @projects = all_archived.limit(projects_per_page).offset(offset)

    respond_to do |format|
      format.html
      format.json { render json: @projects }
    end
  end

  def show
    set_show_date_range
    set_show_tasks_and_base
    date_range = @start_date&.beginning_of_day..@end_date&.end_of_day if @start_date && @end_date
    base_tasks = @project.tasks_with_search(
      q: params[:q], status: params[:status], date_range: date_range,
      created_by: params[:created_by], assignee_id: params[:assignee_id]
    )
    set_show_pagination(base_tasks)
    set_show_extra_data

    respond_to do |format|
      format.html
      format.json { render json: @project.as_json(include: { tasks: { include: :test_cases } }) }
    end
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)

    respond_to do |format|
      if @project.save
        format.html { redirect_to @project, notice: 'Project has been created successfully.' }
        format.json { render json: @project, status: :created, location: @project }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit; end

  def update
    apply_project_management_attributes
    respond_to do |format|
      if @project.save
        format.html { redirect_to @project, notice: 'Project has been updated successfully.' }
        format.json { render json: @project }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    is_archived = @project.deleted_at.present?

    begin
      @project.destroy!
      notice_msg = is_archived ? 'Project has been permanently deleted.' : 'Project has been deleted.'
      redirect_path = is_archived ? archived_projects_path : projects_path

      respond_to do |format|
        format.html { redirect_to redirect_path, notice: notice_msg }
        format.json { head :no_content }
      end
    rescue StandardError => e
      respond_to do |format|
        format.html { redirect_back fallback_location: projects_path, alert: "Failed to delete project: #{e.message}" }
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
      end
    end
  end

  def soft_delete
    respond_to do |format|
      if @project.soft_delete!
        format.html { redirect_to projects_path, notice: 'Project has been moved to archive.' }
        format.json { render json: @project }
      else
        format.html do
          redirect_back fallback_location: projects_path,
                        alert: "Failed to archive project: #{@project.errors.full_messages.join(', ')}"
        end
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  def restore
    respond_to do |format|
      if @project.restore!
        format.html { redirect_to archived_projects_path, notice: 'Project has been restored successfully.' }
        format.json { render json: @project }
      else
        format.html do
          redirect_back fallback_location: archived_projects_path,
                        alert: "Failed to restore project: #{@project.errors.full_messages.join(', ')}"
        end
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_show_date_range
    @selected_preset = params[:date_preset].to_s.presence
    if params[:start_date].present? && params[:end_date].present?
      @start_date = Date.parse(params[:start_date]) rescue nil
      @end_date = Date.parse(params[:end_date]) rescue nil
      @selected_preset = 'custom' if @start_date && @end_date
    elsif @selected_preset.present? && DateRangePreset.key?(@selected_preset)
      range = DateRangePreset.resolve(@selected_preset)
      @start_date = range.begin
      @end_date = range.end
    else
      range = DateRangePreset.resolve('last_30_days')
      @start_date = range.begin
      @end_date = range.end
      @selected_preset = 'last_30_days'
    end
  end

  def set_show_tasks_and_base
    date_range = @start_date&.beginning_of_day..@end_date&.end_of_day
    @tasks = @project.tasks.active
    @tasks = @tasks.where(created_at: date_range) if @start_date && @end_date
  end

  def set_show_pagination(base_tasks)
    @tasks_page = (params[:page] || 1).to_i
    @tasks_per_page = 10
    ordered = base_tasks.order(created_at: :desc)
    @total_tasks = ordered.count
    @total_pages = [ (@total_tasks.to_f / @tasks_per_page).ceil, 1 ].max
    offset = ((@tasks_page - 1) * @tasks_per_page).clamp(0, [ @total_tasks - 1, 0 ].max)
    @root_tasks = ordered.offset(offset).limit(@tasks_per_page).to_a
  end

  def set_show_extra_data
    @status_options = @tasks.where.not(status: [ nil, '' ]).pluck(:status).map(&:downcase).uniq.sort
    @subtasks_count = @tasks.where.not(parent_id: nil).count
    @completed_tasks_count = @tasks.where(status: Task::COMPLETED_STATUSES).count
    @archived_tasks = @project.archived_root_tasks.order(deleted_at: :desc)
    @created_by_options = @project.tasks.active.where.not(created_by_name: [ nil, '' ])
                                  .distinct.pluck(:created_by_name).sort
    @assignee_options = User.where(id: @project.tasks.active.where.not(assignee_id: nil).select(:assignee_id))
                            .order(:name)
    @redmine_projects = can?(:manage, :all) ? cached_redmine_projects : []
  rescue StandardError
    @redmine_projects = []
  end

  def cached_redmine_projects
    Rails.cache.fetch('redmine_projects_list', expires_in: 10.minutes) do
      RedmineService.get_projects_list
    end
  end

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    params.require(:project).permit(
      :name, :description, :open_to_all_users, :product_version, :development_status,
      user_ids: [],
      product_info: %i[owner release_date progress summary tech_stack],
      test_plan: %i[objective scope strategy entry_criteria exit_criteria risks]
    )
  end

  def authorize_admin
    authorize! :manage, Project
  end

  def authorize_project_read
    authorize! :read, @project
  end

  # Assigns permitted attributes, then merges the test-plan schedule which is
  # edited as free text ("Milestone | YYYY-MM-DD" per line) into the json column.
  def apply_project_management_attributes
    @project.assign_attributes(project_params.to_h)
    return unless params[:schedule_text]

    plan = @project.test_plan.is_a?(Hash) ? @project.test_plan : {}
    plan['schedule'] = parse_schedule_text(params[:schedule_text])
    @project.test_plan = plan
  end

  def parse_schedule_text(text)
    text.to_s.split("\n").filter_map do |line|
      milestone, date = line.split('|', 2).map { |part| part.to_s.strip }
      next if milestone.blank?

      { 'milestone' => milestone, 'date' => date.to_s }
    end
  end
end
