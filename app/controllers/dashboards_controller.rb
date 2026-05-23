class DashboardsController < ApplicationController
  def index
    @projects = Project.active.order(created_at: :desc)

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
    @project = @projects.find(params[:id])
    authorize! :read, @project
    load_dashboard_data(@project)
  end

  private

  def load_dashboard_data(project)
    @time_filter = params[:time_filter].presence || 'all'
    
    start_time =
      case @time_filter
      when 'today' then Time.current.beginning_of_day
      when 'week'  then Time.current.beginning_of_week
      when 'month' then Time.current.beginning_of_month
      when 'year'  then Time.current.beginning_of_year
      end

    # 1. Base Scope: Closed tasks in this project
    closed_tasks = project.tasks.active.where(status: 'closed')
    
    # Optional: If you want to filter closed_tasks by when they were closed/updated
    # closed_tasks = closed_tasks.where('updated_at >= ?', start_time) if start_time
    
    @closed_tasks_count = closed_tasks.count

    # 2. Test Results Stats
    test_results_scope = TestResult.active
                                   .joins(test_case: :task)
                                   .where(tasks: { id: closed_tasks.select(:id) })
    
    if start_time
      # Use executed_at if present, else fallback to created_at
      test_results_scope = test_results_scope.where('test_results.executed_at >= :time OR (test_results.executed_at IS NULL AND test_results.created_at >= :time)', time: start_time)
    end

    @test_results_stats = test_results_scope.group('test_results.status').count

    pass_count = @test_results_stats['pass'] || 0
    fail_count = @test_results_stats['fail'] || 0
    total_executed = pass_count + fail_count
    
    @pass_rate =
      if total_executed.positive?
        ((pass_count.to_f / total_executed) * 100).round(1)
      else
        0
      end

    # 3. Bugs Stats
    bugs_scope = Bug.active.joins(:task).where(tasks: { id: closed_tasks.select(:id) })
    bugs_scope = bugs_scope.where('bugs.created_at >= ?', start_time) if start_time
    
    @total_bugs_count = bugs_scope.count
    @open_bugs_count = bugs_scope.where(status: Bug::OPEN_STATUSES).count
    
    @bugs_by_priority = bugs_scope.group(:priority).count
    @bugs_by_status = bugs_scope.group(:status).count
    
    ['high', 'normal', 'low'].each { |p| @bugs_by_priority[p] ||= 0 }
    Bug::STATUSES.each { |s| @bugs_by_status[s] ||= 0 }
  end
end
