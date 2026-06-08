require "rails_helper"

RSpec.describe "TestCases", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project) }
  let(:task) { create(:task, project: project) }
  let!(:test_case) { create(:test_case, task: task) }

  before { login_as admin, scope: :user }

  # ---------------------------------------------------------------------------
  # GET /projects/:project_id/tasks/:task_id/test_cases (scoped)
  # ---------------------------------------------------------------------------
  describe "GET /projects/:project_id/tasks/:task_id/test_cases (via task show)" do
    it "renders task show with test cases" do
      get project_task_path(project, task)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET .../test_cases/:id/cell_history
  # ---------------------------------------------------------------------------
  describe "GET .../test_cases/:id/cell_history" do
    it "returns JSON for a valid field" do
      get cell_history_project_task_test_case_path(project, task, test_case), params: { field: "title" }
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST .../test_cases (create)
  # ---------------------------------------------------------------------------
  describe "POST /projects/:project_id/tasks/:task_id/test_cases" do
    let(:valid_params) { { test_case: { title: "New TC", test_type: "functional", target: "web" } } }
    let(:invalid_params) { { test_case: { title: "" } } }

    it "creates a test case and redirects" do
      expect {
        post project_task_test_cases_path(project, task), params: valid_params
      }.to change(TestCase, :count).by(1)
      expect(response).to redirect_to(project_task_path(project, task))
    end

    it "returns unprocessable on invalid params" do
      post project_task_test_cases_path(project, task),
           params: invalid_params,
           headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH .../test_cases/:id/soft_delete
  # ---------------------------------------------------------------------------
  describe "PATCH .../test_cases/:id/soft_delete" do
    it "soft-deletes and redirects" do
      patch soft_delete_project_task_test_case_path(project, task, test_case)
      expect(response).to redirect_to(project_task_path(project, task))
      test_case.reload
      expect(test_case.deleted_at).not_to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH .../test_cases/:id/restore
  # ---------------------------------------------------------------------------
  describe "PATCH .../test_cases/:id/restore" do
    before { test_case.soft_delete! }

    it "restores the test case" do
      patch restore_project_task_test_case_path(project, task, test_case)
      expect(response).to redirect_to(project_task_path(project, task))
      test_case.reload
      expect(test_case.deleted_at).to be_nil
    end
  end
end
