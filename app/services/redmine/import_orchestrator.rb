module Redmine
  class ImportOrchestrator
    attr_reader :errors, :task, :project

    def initialize(redmine_id, project_id)
      @redmine_id = redmine_id
      @project = Project.find(project_id)
      @errors = []
      @task = nil
    end

    def import
      Rails.logger.info "Start import task from Redmine: #{@redmine_id}"
      fetcher = Redmine::Fetcher.new(@redmine_id)
      issue_data = fetcher.call

      if issue_data.nil?
        @errors << fetcher.error
        return false
      end

      import_from_issue_data(issue_data)
    rescue StandardError => e
      @errors << "Error importing task: #{ensure_utf8(e.message)}"
      Rails.logger.error "Redmine::ImportOrchestrator Error: #{e.message}\n#{e.backtrace.join("\n")}"
      false
    end

    def import_from_issue_data(issue_data)
      @redmine_id = issue_data['id'].to_s
      creator = Redmine::TaskCreator.new(@project)
      @task = creator.create_or_update(issue_data, @redmine_id)
      @errors.concat(creator.errors)

      importer = Redmine::SubtaskImporter.new(@task, @project)
      importer.run
      @errors.concat(importer.errors)

      Rails.logger.info "Task imported successfully: #{ensure_utf8(@task.title)}"
      true
    end

    private

    def ensure_utf8(str)
      str = str.to_s
      str = str.dup if str.frozen?
      str.force_encoding('UTF-8').scrub
    end
  end
end
