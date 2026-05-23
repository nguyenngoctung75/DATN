class DashboardController < ApplicationController
  def index
    if current_user.admin?
      redirect_to admin_dashboard_path
    else
      redirect_to projects_path
    end
  end

  def admin
    authorize! :manage, :all
    @users_count = User.active.count
    @projects_count = Project.active.count
    @tasks_count = Task.active.root_tasks.count
    @recent_users = User.active.order(created_at: :desc).limit(5)
    @recent_projects = Project.active.order(created_at: :desc).limit(5).to_a
    @project_root_tasks_counts = Task.active.root_tasks
                                     .where(project_id: @recent_projects.map(&:id))
                                     .group(:project_id).count
  end

  def user
    @projects = Project.active.order(created_at: :desc)
  end
end
