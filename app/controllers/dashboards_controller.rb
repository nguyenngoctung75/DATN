class DashboardsController < ApplicationController
  def index
    @projects = Project.active.order(created_at: :desc)
    @projects = @projects.where(id: current_user.accessible_project_ids) unless current_user.admin?

    if params[:project_id].present?
      @project = @projects.find_by(id: params[:project_id])
    end
    @project ||= @projects.first

    if @project
      authorize! :read, @project
      load_dashboard_data(@project)
    end

    respond_to do |format|
      format.html { render :project_dashboard }
      format.turbo_stream { render :project_dashboard_update }
    end
  end

  def project_dashboard
    @projects = Project.active.order(created_at: :desc)
    @projects = @projects.where(id: current_user.accessible_project_ids) unless current_user.admin?
    @project = @projects.find(params[:id])
    authorize! :read, @project
    load_dashboard_data(@project)
  end

  private

  def load_dashboard_data(project)
    @time_filter = params[:time_filter].presence || 'all'
    start_time = time_filter_start(@time_filter)
    closed_tasks = project.tasks.active.where(status: 'closed')
    @closed_tasks_count = closed_tasks.count
    load_test_results_stats(closed_tasks, start_time)
    load_bugs_stats(closed_tasks, start_time)
  end

  def time_filter_start(filter)
    case filter
    when 'today' then Time.current.beginning_of_day
    when 'week'  then Time.current.beginning_of_week
    when 'month' then Time.current.beginning_of_month
    when 'year'  then Time.current.beginning_of_year
    end
  end

  def load_test_results_stats(closed_tasks, start_time)
    scope = TestResult.active
                      .joins(test_case: :task)
                      .where(tasks: { id: closed_tasks.select(:id) })
    if start_time
      scope = scope.where(
        'test_results.executed_at >= :time OR ' \
        '(test_results.executed_at IS NULL AND test_results.created_at >= :time)',
        time: start_time
      )
    end
    @test_results_stats = scope.group('test_results.status').count
    pass_count = @test_results_stats['pass'] || 0
    fail_count = @test_results_stats['fail'] || 0
    not_run_count = @test_results_stats['not_run'] || 0
    total = pass_count + fail_count + not_run_count
    @pass_rate = total.positive? ? ((pass_count.to_f / total) * 100).round(2) : 0
  end

  def load_bugs_stats(closed_tasks, start_time)
    scope = Bug.active.joins(:task).where(tasks: { id: closed_tasks.select(:id) })
    scope = scope.where('bugs.created_at >= ?', start_time) if start_time
    @total_bugs_count = scope.count
    @open_bugs_count = scope.where(status: Bug::OPEN_STATUSES).count
    @bugs_by_priority = scope.group(:priority).count
    @bugs_by_status = scope.group(:status).count
    %w[high normal low].each { |p| @bugs_by_priority[p] ||= 0 }
    Bug::STATUSES.each { |s| @bugs_by_status[s] ||= 0 }
  end
end
