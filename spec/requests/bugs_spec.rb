require "rails_helper"

RSpec.describe "Bugs", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project) }
  let(:task) { create(:task, project: project) }
  let!(:bug) { create(:bug, task: task) }

  before { login_as admin, scope: :user }

  # ---------------------------------------------------------------------------
  # GET /projects/:project_id/tasks/:task_id/bugs (index)
  # ---------------------------------------------------------------------------
  describe "GET /projects/:project_id/tasks/:task_id/bugs" do
    it "returns 200" do
      get project_task_bugs_path(project, task)
      expect(response).to have_http_status(:ok)
    end

    it "filters by category" do
      create(:bug, task: task, category: "prod")
      get project_task_bugs_path(project, task), params: { category: "prod" }
      expect(response).to have_http_status(:ok)
    end

    it "filters by priority" do
      create(:bug, task: task, priority: "high")
      get project_task_bugs_path(project, task), params: { priority: "high" }
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET .../bugs/:id (show)
  # ---------------------------------------------------------------------------
  describe "GET .../bugs/:id" do
    it "returns 200" do
      get project_task_bug_path(project, task, bug)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST .../bugs (create)
  # ---------------------------------------------------------------------------
  describe "POST .../bugs" do
    let(:valid_params) { { bug: { title: "New Bug", category: "stg_vn", priority: "normal", status: "new" } } }
    let(:invalid_params) { { bug: { title: "", category: "", priority: "" } } }

    it "creates a bug and redirects" do
      expect {
        post project_task_bugs_path(project, task), params: valid_params
      }.to change(Bug, :count).by(1)
      expect(response).to redirect_to(project_task_bugs_path(project, task))
    end

    it "returns unprocessable on missing required fields" do
      post project_task_bugs_path(project, task), params: invalid_params
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH .../bugs/:id (update)
  # ---------------------------------------------------------------------------
  describe "PATCH .../bugs/:id" do
    it "updates the bug and redirects" do
      patch project_task_bug_path(project, task, bug),
            params: { bug: { title: "Updated Bug" } }
      expect(response).to redirect_to(project_task_bug_path(project, task, bug))
      bug.reload
      expect(bug.title).to eq("Updated Bug")
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH .../bugs/:id/soft_delete
  # ---------------------------------------------------------------------------
  describe "PATCH .../bugs/:id/soft_delete" do
    it "soft-deletes the bug" do
      patch soft_delete_project_task_bug_path(project, task, bug)
      expect(response).to redirect_to(project_task_bugs_path(project, task))
      bug.reload
      expect(bug.deleted_at).not_to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH .../bugs/:id/restore
  # ---------------------------------------------------------------------------
  describe "PATCH .../bugs/:id/restore" do
    before { bug.soft_delete! }

    it "restores a soft-deleted bug" do
      patch restore_project_task_bug_path(project, task, bug)
      expect(response).to redirect_to(project_task_bugs_path(project, task))
      bug.reload
      expect(bug.deleted_at).to be_nil
    end
  end

# ---------------------------------------------------------------------------
  # GET .../bugs/:id/cell_history
  # ---------------------------------------------------------------------------
  describe "GET .../bugs/:id/cell_history" do
    it "returns JSON for a valid field" do
      get cell_history_project_task_bug_path(project, task, bug), params: { field: "content" }
      expect(response).to have_http_status(:ok)
    end
  end
end
