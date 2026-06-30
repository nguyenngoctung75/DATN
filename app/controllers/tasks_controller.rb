class TasksController < ApplicationController
  before_action :set_project, only: %i[new create]
  before_action :set_task, except: %i[index new create]
  before_action :require_project_membership!
  authorize_resource

  def index
    if params[:project_id]
      @project = Project.find(params[:project_id])
      base_scope = @project.tasks.active.root_tasks
    elsif current_user.admin?
      base_scope = Task.active.root_tasks
    else
      base_scope = Task.active.root_tasks.where(project_id: current_user.accessible_project_ids)
    end

    @stats_subtasks_count = Task.active.where.not(parent_id: nil).count
    @stats_completed_count = Task.active.where(status: [ 'closed' ]).count

    @status_options = base_scope.distinct.pluck(:status).compact.sort

    @tasks = base_scope.includes(:project, :assignee, :test_cases)
    @tasks = @tasks.with_status(params[:status]) if params[:status].present?
    @tasks = @tasks.search(params[:q]) if params[:q].present?

    @per_page = 10
    @total_tasks = @tasks.count
    @current_page = (params[:page].presence || 1).to_i
    @total_pages = [ (@total_tasks.to_f / @per_page).ceil, 1 ].max
    @current_page = [ [ @current_page, 1 ].max, @total_pages ].min
    @tasks = @tasks.order(updated_at: :desc).offset((@current_page - 1) * @per_page).limit(@per_page)
  end

  def show
    @test_case = @task.test_cases.build
    @test_cases_page = (params[:tc_page] || 1).to_i
    @test_cases_per_page = 10
    @tc_sort = params[:tc_sort] == 'desc' ? 'desc' : 'asc'
    @show_archived = params[:show_archived] == '1'

    ordered_tc = @task.test_cases_ordered(sort: @tc_sort, show_archived: @show_archived)
    @total_test_cases = ordered_tc.count
    @total_tc_pages = [ (@total_test_cases.to_f / @test_cases_per_page).ceil, 1 ].max
    tc_start = ((@test_cases_page - 1) * @test_cases_per_page).clamp(0, [ @total_test_cases - 1, 0 ].max)
    @paginated_test_cases = ordered_tc.offset(tc_start).limit(@test_cases_per_page).to_a
    @existing_titles = @task.test_cases.active.pluck(:title).uniq.compact.sort

    @ci_builds = @task.ci_builds.recent.limit(20)

    respond_to do |format|
      format.html
      format.json { render json: @task.as_json(include: %i[test_cases assignee]) }
    end
  end

  def report
    @ci_builds = @task.ci_builds.recent.limit(20)
    @active_bugs_count = @task.bugs.active.count
    @total_test_cases = @task.total_test_cases_count
  end

  def new
    @task = @project.tasks.build
  end

  def edit; end

  def create
    @task = @project.tasks.build(task_params)
    @task.created_by_name = current_user.name || current_user.email

    if @task.save
      run = enqueue_manual_import_if_needed(@task)
      notice = run ? 'Task created. Import is running in background.' : 'Create task successfully.'

      respond_to do |format|
        format.html do
          redirect_to(run ? import_run_path(run) : project_task_path(@project, @task), notice: notice)
        end
        format.json { render json: { task: @task, import_run_id: run&.id }, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @task.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def update
    if @task.update(task_params)
      respond_to do |format|
        format.html { redirect_to project_task_path(@task.project, @task), notice: 'Update task successfully.' }
        format.json { render json: @task }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { errors: @task.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @task.destroy
    respond_to do |format|
      format.html { redirect_to tasks_path, notice: 'Delete task successfully.' }
      format.json { head :no_content }
    end
  end

  def soft_delete
    @task.soft_delete!
    respond_to do |format|
      format.html { redirect_to project_path(@task.project), notice: 'Soft delete task successfully.' }
      format.json { head :no_content }
    end
  end

  def restore
    @task.restore!
    respond_to do |format|
      format.html { redirect_to project_path(@task.project), notice: 'Restore task successfully.' }
      format.json { render json: @task }
    end
  end

  def create_subtask
    @subtask = @task.subtasks.build(task_params)
    @subtask.project = @project
    @subtask.created_by_name = current_user.name || current_user.email

    if @subtask.save
      redirect_to project_task_path(@project, @task), notice: 'Subtask created successfully.'
    else
      redirect_to project_task_path(@project, @task),
alert: "Failed to create subtask: #{@subtask.errors.full_messages.join(', ')}"
    end
  end

  def promote_to_subtask
    function_name = params[:function]

    if function_name.blank?
      redirect_to project_task_path(@project, @task), alert: 'Function name is required.'
      return
    end

    subtask, count = @task.promote_to_subtask!(
      function_name,
      project: @project,
      created_by_name: current_user.name || current_user.email
    )

    if subtask
      redirect_to project_task_path(@project, subtask),
                  notice: "Promoted '#{function_name}' to subtask successfully. Moved #{count} test cases."
    else
      redirect_to project_task_path(@project, @task), alert: 'Failed to create subtask.'
    end
  end

  def update_device_config
    if @task.update(device_config: params[:device_config])
      redirect_to project_task_path(@project, @task), notice: 'Device configuration has been updated successfully.'
    else
      redirect_to project_task_path(@project, @task), alert: 'An error occurred while updating device configuration.'
    end
  end

  def promote_all_to_subtask
    subtask, count = @task.promote_all_to_subtask!(
      project: @project,
      created_by_name: current_user.name || current_user.email
    )

    if subtask
      redirect_to project_task_path(@project, subtask),
                  notice: "Moved all #{count} test cases to new subtask successfully."
    else
      redirect_to project_task_path(@project, @task), alert: 'Failed to create subtask.'
    end
  end

  private

  def enqueue_manual_import_if_needed(task)
    return nil unless task.testcase_link.present? || task.bug_link.present?

    run = ImportRun.create!(
      project: @project,
      triggered_by: current_user,
      import_type: 'manual',
      status: 'pending',
      params: { 'task_id' => task.id }
    )
    ManualImportJob.perform_later(run.id)
    run
  end

  def set_project
    @project = Project.find(params[:project_id]) if params[:project_id]
  end

  def set_task
    @task = Task.includes(:project, :subtasks).find(params[:id])
    @project = @task.project
  end

  def task_params
    params.require(:task).permit(
      :title, :description, :status, :assignee_id, :parent_id,
      :estimated_time, :spent_time, :percent_done, :start_date, :due_date,
      :testcase_link, :bug_link, :issue_link, :device_config,
      :test_phase, :testing_type,
      kpi_targets: Task::KPIS.keys
    )
  end
end
