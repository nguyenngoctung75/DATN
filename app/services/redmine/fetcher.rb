module Redmine
  class Fetcher
    attr_reader :error

    def initialize(redmine_id)
      @redmine_id = redmine_id
      @error = nil
    end

    def call
      unless @redmine_id.to_s.match?(/^\d+$/)
        @error = 'Please provide issue ID (number) instead of name'
        return nil
      end

      issue_data = RedmineService.get_issues(@redmine_id)
      if issue_data.nil?
        @error = "Cannot find issue from Redmine with ID: #{@redmine_id}"
        return nil
      end

      issue_data
    end
  end
end
