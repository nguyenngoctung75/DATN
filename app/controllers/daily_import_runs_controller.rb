# frozen_string_literal: true

class DailyImportRunsController < ApplicationController
  before_action :set_project
  before_action :authorize_read

  def index
    @runs = @project.daily_import_runs.recent.limit(50)
  end

  def show
    @run = @project.daily_import_runs.find(params[:id])
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def authorize_read
    authorize! :read, @project
  end
end
