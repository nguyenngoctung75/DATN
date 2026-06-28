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
    # "Root task" = top-level task per Project#root_tasks semantics (parent_id NULL, or
    # parent outside this project). Matches the count shown on /projects and project show.
    @tasks_count = Task.active
                       .where('tasks.parent_id IS NULL OR NOT EXISTS (' \
                              'SELECT 1 FROM tasks p WHERE p.id = tasks.parent_id ' \
                              'AND p.project_id = tasks.project_id)')
                       .count
    @recent_users = User.active.order(created_at: :desc).limit(5)
    @recent_projects = Project.active.order(created_at: :desc).limit(5).to_a
    @project_root_tasks_counts = @recent_projects.to_h { |p| [ p.id, p.task_count ] }
  end

  def user
    @projects = Project.active.order(created_at: :desc)
  end
end
