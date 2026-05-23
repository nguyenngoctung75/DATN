class ProjectHistoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin
  before_action :set_project, if: -> { params[:project_id].present? }

  # GET /project_histories
  # Display all histories of all projects
  def index
    @project_histories = ActivityLog
                         .includes(:trackable, :user)
                         .for_projects
                         .then { |scope| filter_by_project(scope) }
                         .then { |scope| filter_by_action(scope) }

    respond_to do |format|
      format.html
      format.json { render json: @project_histories }
    end
  end

  # GET /project_histories/:id
  # Display details of a single history
  def show
    @project_history = ActivityLog.find(params[:id])
    @project ||= @project_history.trackable

    respond_to do |format|
      format.html
      format.json { render json: @project_history }
    end
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def filter_by_project(scope)
    return scope unless @project

    scope.where(trackable_id: @project.id)
  end

  def filter_by_action(scope)
    return scope unless params[:action_filter].present?

    scope.by_action(params[:action_filter])
  end

  def authorize_admin
    authorize! :manage, ActivityLog
  end
end
