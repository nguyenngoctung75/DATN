require "rails_helper"

RSpec.describe "Task report & test phase", type: :request do
  let(:admin) { create(:user, :admin) }
  let!(:project) { create(:project) }
  let!(:task) { create(:task, project: project) }

  before { login_as admin, scope: :user }

  describe "GET /projects/:project_id/tasks/:id/report" do
    it "renders the report page" do
      get report_project_task_path(project, task)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Task Report")
      expect(response.body).to include("CI/CD History")
    end
  end

  describe "PATCH /projects/:project_id/tasks/:id (test_phase)" do
    it "updates the test phase" do
      patch project_task_path(project, task),
            params: { task: { test_phase: "executing" } },
            headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:ok)
      expect(task.reload.test_phase).to eq("executing")
    end

    it "rejects an invalid test phase" do
      patch project_task_path(project, task),
            params: { task: { test_phase: "bogus" } },
            headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
