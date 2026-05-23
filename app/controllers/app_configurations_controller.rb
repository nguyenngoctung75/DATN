class AppConfigurationsController < ApplicationController
  before_action :set_configuration
  before_action :authorize_app_configuration

  def edit
    set_edit_vars
  rescue StandardError => e
    @redmine_projects = []
    flash.now[:alert] = "Could not fetch Redmine projects: #{e.message}"
  end

  def update
    unless valid_project_redmine_links?
      set_edit_vars
      render :edit
      return
    end
    update_project_redmine_links
    redirect_to edit_app_configuration_path, notice: 'Configuration updated successfully.'
  end

  private

  def set_edit_vars
    @projects = Project.all
    @redmine_projects = Rails.cache.fetch('redmine_projects_list', expires_in: 10.minutes) do
      RedmineService.get_projects_list
    end || []
  end

  def set_configuration
    @configuration = AppConfiguration.instance
  end

  def authorize_app_configuration
    action = action_name.to_sym == :update ? :update : :edit
    authorize! action, @configuration
  end

  def valid_project_redmine_links?
    redmine_ids = params[:project_redmine_ids] || {}
    enabled = params[:project_daily_import_enabled] || {}
    invalid = enabled.select { |_id, v| v == '1' }.keys.select { |id| redmine_ids[id].to_s.blank? }
    if invalid.any?
      names = Project.where(id: invalid).pluck(:name).join(', ')
      flash.now[:alert] = "Please select a Redmine project for enabled items: #{names}"
      return false
    end
    true
  end

  def update_project_redmine_links
    redmine_ids = params[:project_redmine_ids] || {}
    enabled = params[:project_daily_import_enabled] || {}
    projects = Project.where(id: redmine_ids.keys).index_by { |p| p.id.to_s }
    redmine_ids.each_key do |project_id|
      p = projects[project_id]
      next unless p

      p.update(
        redmine_project_id: redmine_ids[project_id].to_s.presence,
        daily_import_enabled: enabled[project_id] == '1'
      )
    end
  end
end
