class DailyImportJob < ApplicationJob
  queue_as :default

  def perform
    unless ENV.fetch('DAILY_IMPORT_ENABLED', 'true') == 'true'
      Rails.logger.info 'DailyImportJob: Skipped (global daily import disabled by ENV)'
      return
    end

    projects = Project.where(daily_import_enabled: true).where.not(redmine_project_id: [ nil, '' ])
    unless projects.exists?
      Rails.logger.info 'DailyImportJob: Skipped (no projects with Redmine link)'
      return
    end

    projects.find_each { |project| DailyImportOrchestrator.new(project).run }
  end
end
