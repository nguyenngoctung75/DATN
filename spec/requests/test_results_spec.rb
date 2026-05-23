require "rails_helper"

RSpec.describe "TestResults", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project) }
  let(:task) { create(:task, project: project) }
  let(:test_case) { create(:test_case, task: task) }
  let!(:test_result) { create(:test_result, test_case: test_case) }

  before { login_as admin, scope: :user }

  # ---------------------------------------------------------------------------
  # GET /test_results (standalone index — HTML view not available, JSON is primary format)
  # ---------------------------------------------------------------------------
  describe "GET /test_results" do
    it "returns JSON listing" do
      get test_results_path, params: { format: :json }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    it "filters by status (JSON)" do
      get test_results_path, params: { status: "pass", format: :json }
      expect(response).to have_http_status(:ok)
    end

    it "filters by task_id via join (JSON)" do
      get test_results_path, params: { task_id: task.id, format: :json }
      expect(response).to have_http_status(:ok)
    end

    it "filters by project_id via join (JSON)" do
      get test_results_path, params: { project_id: project.id, format: :json }
      expect(response).to have_http_status(:ok)
    end

    it "filters by case_id (JSON)" do
      get test_results_path, params: { case_id: test_case.id, format: :json }
      expect(response).to have_http_status(:ok)
    end

    it "returns full nested associations in JSON" do
      get test_results_path, params: { format: :json }
      body = response.parsed_body
      expect(body.first).to include("id", "status")
    end
  end

  # ---------------------------------------------------------------------------
  # GET /test_results/:id (standalone show — JSON)
  # ---------------------------------------------------------------------------
  describe "GET /test_results/:id" do
    it "returns JSON with nested associations" do
      get test_result_path(test_result), params: { format: :json }
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body).to include("id" => test_result.id, "status" => test_result.status)
    end
  end

  # ---------------------------------------------------------------------------
  # POST .../test_cases/:test_case_id/test_results (create)
  # ---------------------------------------------------------------------------
  describe "POST /projects/.../test_cases/:test_case_id/test_results" do
    let(:valid_params) { { test_result: { status: "pass", device: "PC" } } }

    it "creates a test result and redirects" do
      expect {
        post project_task_test_case_test_results_path(project, task, test_case),
             params: valid_params
      }.to change(TestResult, :count).by(1)
      expect(response).to redirect_to([project, task, test_case])
    end

    it "sets executed_by to current_user" do
      post project_task_test_case_test_results_path(project, task, test_case),
           params: valid_params
      expect(TestResult.order(:id).last.executed_by).to eq(admin)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /test_results/:id/soft_delete
  # ---------------------------------------------------------------------------
  describe "PATCH /test_results/:id/soft_delete" do
    it "soft-deletes the test result" do
      patch soft_delete_test_result_path(test_result)
      test_result.reload
      expect(test_result.deleted_at).not_to be_nil
    end
  end
end
