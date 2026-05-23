require 'rails_helper'

RSpec.describe 'ImportRuns', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project) }
  let!(:run) do
    ImportRun.create!(
      project: project, triggered_by: admin, import_type: 'manual',
      status: 'running', total_count: 4, processed_count: 2, imported_count: 2
    )
  end

  before { login_as admin, scope: :user }

  describe 'GET /import_runs/:id' do
    it 'renders HTML successfully' do
      get import_run_path(run)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Import #{run.import_type.humanize}")
    end

    it 'returns JSON status payload' do
      get import_run_path(run, format: :json)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('running')
      expect(json['progress_percent']).to eq(50)
      expect(json['imported_count']).to eq(2)
    end
  end

  describe 'GET /import_runs/:id/status' do
    it 'returns JSON with current state' do
      get status_import_run_path(run)
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to include('status', 'progress_percent', 'processed_count', 'total_count')
    end
  end
end
