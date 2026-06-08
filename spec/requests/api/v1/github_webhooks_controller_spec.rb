require 'rails_helper'

RSpec.describe 'Api::V1::GithubWebhooks', type: :request do
  let(:secret)   { 'test_secret' }
  let(:endpoint) { '/api/v1/github_webhooks/ci_result' }
  let!(:project) { create(:project) }
  let(:base_payload) do
    {
      commit_sha:       'abcdef1234567890',
      branch:           'feat/x',
      base_branch:      'main',
      status:           'success',
      workflow_run_id:  '17000000001',
      author:           'alice',
      github_url:       'https://github.com/org/repo/actions/runs/1',
      pr_url:           'https://github.com/org/repo/pull/42',
      pr_number:        42,
      pr_title:         'Add X',
      repository:       'org/repo',
      redmine_link:     'https://redmine.local/issues/123',
      redmine_issue_id: 123,
      event:            'pull_request',
      action:           'synchronize',
      timestamp:        Time.current.iso8601
    }
  end

  around do |example|
    original_secret  = ENV['CI_WEBHOOK_SECRET']
    original_default = ENV['CI_DEFAULT_PROJECT_ID']
    ENV['CI_WEBHOOK_SECRET']    = secret
    ENV['CI_DEFAULT_PROJECT_ID'] = project.id.to_s
    example.run
  ensure
    ENV['CI_WEBHOOK_SECRET']    = original_secret
    ENV['CI_DEFAULT_PROJECT_ID'] = original_default
  end

  def sign(body)
    'sha256=' + OpenSSL::HMAC.hexdigest('SHA256', secret, body)
  end

  def post_webhook(payload, signature: nil)
    body = payload.to_json
    post endpoint,
         params: body,
         headers: {
           'Content-Type'        => 'application/json',
           'X-Hub-Signature-256' => signature || sign(body)
         }
  end

  context 'when signature is invalid' do
    it 'returns 401' do
      post_webhook(base_payload, signature: 'sha256=deadbeef')
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 401 when signature header is missing' do
      body = base_payload.to_json
      post endpoint, params: body, headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'when payload is malformed JSON' do
    it 'returns 400' do
      body = 'not-json'
      post endpoint,
           params: body,
           headers: {
             'Content-Type'        => 'application/json',
             'X-Hub-Signature-256' => sign(body)
           }
      expect(response).to have_http_status(:bad_request)
    end
  end

  context 'when redmine link is missing' do
    it 'returns 422' do
      post_webhook(base_payload.merge(redmine_link: '', redmine_issue_id: 0))
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  context 'when task with redmine_id already exists' do
    let!(:task) { create(:task, project: project, redmine_id: 123) }

    it 'creates CiBuild linked to task and returns 201 (status=success)' do
      expect { post_webhook(base_payload) }.to change(CiBuild, :count).by(1)
      expect(response).to have_http_status(:created)
      expect(CiBuild.last.task_id).to eq(task.id)
      expect(CiBuild.last.status).to eq('success')
    end

    it 'accepts status=failed' do
      expect { post_webhook(base_payload.merge(status: 'failed', workflow_run_id: '17000000002')) }
        .to change(CiBuild, :count).by(1)
      expect(response).to have_http_status(:created)
      expect(CiBuild.last.status).to eq('failed')
    end

    it 'accepts status=not_run' do
      expect { post_webhook(base_payload.merge(status: 'not_run', workflow_run_id: '17000000003')) }
        .to change(CiBuild, :count).by(1)
      expect(response).to have_http_status(:created)
      expect(CiBuild.last.status).to eq('not_run')
    end

    it 'is idempotent on workflow_run_id (upsert)' do
      post_webhook(base_payload)
      expect { post_webhook(base_payload) }.not_to change(CiBuild, :count)
    end

    it 'creates a Notification with CI title' do
      expect { post_webhook(base_payload) }.to change(Notification, :count).by(1)
      expect(Notification.last.title).to match(/CI/)
    end
  end

  context 'when task does not exist (auto-import via Redmine)' do
    let(:imported_task) { create(:task, project: project, redmine_id: 123) }

    it 'calls RedmineImportService and persists CiBuild' do
      service_double = instance_double(
        'Redmine::ImportOrchestrator',
        import: true,
        task: imported_task,
        errors: []
      )
      allow(RedmineImportService).to receive(:new).and_return(service_double)

      expect { post_webhook(base_payload) }.to change(CiBuild, :count).by(1)
      expect(response).to have_http_status(:created)
      expect(CiBuild.last.task_id).to eq(imported_task.id)
    end

    it 'persists CiBuild without task and returns 422 when import fails' do
      service_double = instance_double(
        'Redmine::ImportOrchestrator',
        import: false,
        task: nil,
        errors: [ 'redmine unreachable' ]
      )
      allow(RedmineImportService).to receive(:new).and_return(service_double)

      expect { post_webhook(base_payload) }.to change(CiBuild, :count).by(1)
      expect(CiBuild.last.task_id).to be_nil
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
