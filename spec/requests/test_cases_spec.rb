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

  # ---------------------------------------------------------------------------
  # DELETE .../test_cases/:id (hard delete from archived view)
  # ---------------------------------------------------------------------------
  describe "DELETE .../test_cases/:id" do
    let!(:step) { test_case.test_steps.create!(step_number: 1) }
    let!(:content) { step.test_step_contents.create!(content_type: "text", content_value: "do it") }

    it "hard-deletes the test case and cascades to steps and contents" do
      expect {
        delete project_task_test_case_path(project, task, test_case),
               params: { show_archived: "1" },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }
      }.to change(TestCase, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(TestStep.where(id: step.id)).to be_empty
      expect(TestStepContent.where(id: content.id)).to be_empty
    end
  end

  # ---------------------------------------------------------------------------
  # POST .../test_cases/ai_generate
  # ---------------------------------------------------------------------------
  describe "POST .../test_cases/ai_generate" do
    before { AppConfiguration.instance.update!(ai_tc_enabled: true) }

    around do |example|
      if defined?(ClimateControl)
        ClimateControl.modify(GEMINI_API_KEY: "test-key") { example.run }
      else
        original = ENV["GEMINI_API_KEY"]
        ENV["GEMINI_API_KEY"] = "test-key"
        begin
          example.run
        ensure
          ENV["GEMINI_API_KEY"] = original
        end
      end
    end

    it "creates an ImportRun and enqueues the job" do
      allow(AiGenerateTcJob).to receive(:perform_later)
      expect {
        post ai_generate_project_task_test_cases_path(project, task),
             params: { description: "Login feature", count: 5 }
      }.to change { ImportRun.where(import_type: "ai_generate_tc").count }.by(1)
      expect(AiGenerateTcJob).to have_received(:perform_later).with(ImportRun.last.id)
      expect(response).to redirect_to(import_run_path(ImportRun.last))
    end

    it "rejects a blank description" do
      post ai_generate_project_task_test_cases_path(project, task),
           params: { description: "" },
           headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects when the feature is disabled" do
      AppConfiguration.instance.update!(ai_tc_enabled: false)
      post ai_generate_project_task_test_cases_path(project, task),
           params: { description: "Login feature" },
           headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
