# frozen_string_literal: true

module Api
  module V1
    class GithubWebhooksController < ActionController::API
      before_action :verify_signature!

      def ci_result
        payload = JSON.parse(request.raw_post)

        redmine_id = extract_redmine_id(payload['redmine_link']) ||
                     payload['redmine_issue_id'].to_i.nonzero?

        if redmine_id.blank?
          return render json: { error: 'redmine_link missing or invalid' },
                        status: :unprocessable_entity
        end

        task = Task.find_by(redmine_id: redmine_id) || import_task_from_redmine(redmine_id)

        unless task
          persist_ci_build!(payload, nil)
          return render json: { error: 'task import failed', errors: @import_errors },
                        status: :unprocessable_entity
        end

        build = persist_ci_build!(payload, task)
        Notification.create!(
          category: 'system',
          title:    notification_title(build, task),
          message:  notification_message(build, task),
          link:     build.pr_url.presence || build.github_url
        )

        render json: { ok: true, ci_build_id: build.id, task_id: task.id },
               status: :created
      rescue JSON::ParserError
        render json: { error: 'invalid json' }, status: :bad_request
      end

      private

      def verify_signature!
        secret = ENV.fetch('CI_WEBHOOK_SECRET')
        header = request.headers['X-Hub-Signature-256'].to_s
        return head(:unauthorized) if header.blank?

        expected = 'sha256=' + OpenSSL::HMAC.hexdigest('SHA256', secret, request.raw_post)
        return if ActiveSupport::SecurityUtils.secure_compare(expected, header)

        head(:unauthorized)
      end

      def extract_redmine_id(link)
        m = link.to_s.match(%r{/issues/(\d+)})
        m && m[1].to_i.nonzero?
      end

      def import_task_from_redmine(redmine_id)
        project_id = default_project_id
        unless project_id
          @import_errors = [ 'no default project configured (set CI_DEFAULT_PROJECT_ID)' ]
          return nil
        end

        service = RedmineImportService.new(redmine_id.to_s, project_id)
        if service.import
          service.task
        else
          @import_errors = service.errors
          Rails.logger.warn(
            "[CI webhook] Redmine import failed for ##{redmine_id}: #{service.errors.join('; ')}"
          )
          nil
        end
      end

      def default_project_id
        ENV.fetch('CI_DEFAULT_PROJECT_ID') { Project.order(:id).first&.id }
      end

      def persist_ci_build!(payload, task)
        CiBuild.find_or_initialize_by(workflow_run_id: payload['workflow_run_id']).tap do |b|
          b.assign_attributes(
            task:             task,
            commit_sha:       payload['commit_sha'],
            branch:           payload['branch'],
            base_branch:      payload['base_branch'],
            status:           payload['status'],
            author:           payload['author'],
            github_url:       payload['github_url'],
            pr_url:           payload['pr_url'],
            pr_number:        payload['pr_number'],
            pr_title:         payload['pr_title'],
            repository:       payload['repository'],
            redmine_link:     payload['redmine_link'],
            redmine_issue_id: payload['redmine_issue_id'],
            event_name:       payload['event'],
            event_action:     payload['action'],
            occurred_at:      parse_time(payload['timestamp']),
            raw_payload:      payload
          )
          b.save!
        end
      end

      def parse_time(iso)
        Time.iso8601(iso.to_s)
      rescue ArgumentError
        Time.current
      end

      def notification_title(build, task)
        emoji = build.succeeded? ? '✅' : '❌'
        "#{emoji} CI #{build.status} — #{task.title.to_s.truncate(50)} (PR ##{build.pr_number})"
      end

      def notification_message(build, _task)
        "Redmine ##{build.redmine_issue_id} · #{build.short_sha} by #{build.author} on #{build.branch}"
      end
    end
  end
end
