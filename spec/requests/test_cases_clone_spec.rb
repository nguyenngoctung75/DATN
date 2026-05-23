require 'rails_helper'

RSpec.describe 'TestCases clone', type: :request do
  let(:admin)       { create(:user, :admin) }
  let(:project)     { create(:project) }
  let(:source_task) { create(:task, project: project) }
  let(:dest_task)   { create(:task, project: project) }
  let!(:tc)         { create(:test_case, task: source_task) }

  before { login_as admin, scope: :user }

  describe 'POST /projects/:project_id/tasks/:task_id/test_cases/:id/clone' do
    it 'clones a single test case into the destination task' do
      expect {
        post clone_project_task_test_case_path(project, source_task, tc),
             params: { destination_task_id: dest_task.id }
      }.to change { dest_task.reload.test_cases.count }.by(1)
      expect(response).to redirect_to(project_task_path(project, source_task))
    end

    it 'returns JSON with cloned_count when requested' do
      post clone_project_task_test_case_path(project, source_task, tc),
           params: { destination_task_id: dest_task.id }, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['cloned_count']).to eq(1)
    end
  end

  describe 'POST /projects/:project_id/tasks/:task_id/test_cases/clone_bulk' do
    let!(:tc2) { create(:test_case, task: source_task) }

    it 'clones selected source_ids' do
      expect {
        post clone_bulk_project_task_test_cases_path(project, source_task),
             params: { destination_task_id: dest_task.id, source_ids: [ tc.id, tc2.id ] }
      }.to change { dest_task.reload.test_cases.count }.by(2)
    end

    it 'clones all active TCs when source_ids is empty' do
      expect {
        post clone_bulk_project_task_test_cases_path(project, source_task),
             params: { destination_task_id: dest_task.id }
      }.to change { dest_task.reload.test_cases.count }.by(2)
    end

    it 'returns 422 when destination is missing/invalid' do
      post clone_bulk_project_task_test_cases_path(project, source_task),
           params: { destination_task_id: 0, source_ids: [ tc.id ] }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects cross-project cloning' do
      other = create(:task, project: create(:project))
      post clone_bulk_project_task_test_cases_path(project, source_task),
           params: { destination_task_id: other.id, source_ids: [ tc.id ] }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to match(/Cross-project/)
    end

    it 'enqueues a job and returns 202 for large batches' do
      stub_const('TestCaseClone::Dispatcher::SYNC_THRESHOLD', 1)
      post clone_bulk_project_task_test_cases_path(project, source_task),
           params: { destination_task_id: dest_task.id }, as: :json
      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body['import_run_id']).to be_present
    end
  end

end
