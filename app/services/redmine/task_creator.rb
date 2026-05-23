module Redmine
  class TaskCreator
    attr_reader :task, :errors

    def initialize(project)
      @project = project
      @errors = []
      @task = nil
    end

    def create_or_update(issue_data, redmine_id)
      @task = @project.tasks.find_or_initialize_by(
        title: ensure_utf8(issue_data['subject'])
      )
      @task.assign_attributes(build_attributes(issue_data, redmine_id))

      unless @task.save
        @errors << "Cannot save task: #{ensure_utf8(@task.errors.full_messages.join(', '))}"
        raise 'Cannot save task'
      end

      @task
    end

    private

    def build_attributes(issue_data, redmine_id)
      custom_fields = parse_custom_fields(issue_data['custom_fields'] || [])
      internal_parent_id = find_internal_parent_id(issue_data)

      {
        redmine_id: redmine_id.to_s,
        parent_id: internal_parent_id,
        description: ensure_utf8(issue_data['description']),
        status: ensure_utf8(issue_data.dig('status', 'name')),
        estimated_time: parse_hours(issue_data['estimated_hours']),
        spent_time: parse_hours(issue_data['spent_hours']),
        percent_done: issue_data['done_ratio'],
        start_date: issue_data['start_date'],
        due_date: issue_data['due_date'],
        testcase_link: ensure_utf8(custom_fields['testcase_link']),
        number_of_test_cases: custom_fields['number_of_test_cases'],
        bug_link: ensure_utf8(custom_fields['bug_link']),
        stg_bugs_vn: custom_fields['stg_bugs_vn'],
        stg_bugs_jp: custom_fields['stg_bugs_jp'],
        prod_bugs: custom_fields['production_bugs'],
        created_by_name: ensure_utf8(issue_data.dig('assigned_to', 'name'))
      }
    end

    def find_internal_parent_id(issue_data)
      parent_redmine_id = issue_data.dig('parent', 'id')
      return nil unless parent_redmine_id.present?

      Task.find_by(redmine_id: parent_redmine_id.to_s)&.id
    end

    def parse_custom_fields(custom_fields)
      custom_fields.each_with_object({}) do |field, result|
        name = ensure_utf8(field['name']).downcase.strip.gsub(/ +/, '_').gsub(/[()]/, '')
        result[name] = field['value']
      end
    end

    def parse_hours(hours)
      hours.nil? ? nil : hours.to_f
    end

    def ensure_utf8(str)
      str = str.to_s
      str = str.dup if str.frozen?
      str.force_encoding('UTF-8').scrub
    end
  end
end
