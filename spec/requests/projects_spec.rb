require "rails_helper"

RSpec.describe "Projects", type: :request do
  let(:admin) { create(:user, :admin) }
  let!(:project) { create(:project) }

  before do
    login_as admin, scope: :user
    # RedmineService may be called in ProjectsController#show — stub to avoid HTTP
    allow(RedmineService).to receive(:get_projects_list).and_return([])
  end

  # ---------------------------------------------------------------------------
  # GET /projects (index)
  # ---------------------------------------------------------------------------
  describe "GET /projects" do
    it "returns 200" do
      get projects_path
      expect(response).to have_http_status(:ok)
    end

    it "paginates" do
      get projects_path, params: { page: 1 }
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /projects/archived
  # ---------------------------------------------------------------------------
  describe "GET /projects/archived" do
    before { project.soft_delete! }

    it "returns 200" do
      get archived_projects_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /projects/:id (show — fat action with date presets)
  # ---------------------------------------------------------------------------
  describe "GET /projects/:id" do
    it "returns 200 with default (last_30_days) preset" do
      get project_path(project)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 with explicit date preset" do
      get project_path(project), params: { date_preset: "this_week" }
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 with custom date range" do
      get project_path(project), params: { start_date: "2025-01-01", end_date: "2025-12-31" }
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 with search query" do
      task = create(:task, project: project, title: "Login refactor")
      get project_path(project), params: { q: "Login" }
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 with status filter" do
      create(:task, project: project, status: "in progress")
      get project_path(project), params: { status: "in_progress" }
      expect(response).to have_http_status(:ok)
    end

    it "returns JSON" do
      get project_path(project, format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("id" => project.id)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /projects (create — admin only)
  # ---------------------------------------------------------------------------
  describe "POST /projects" do
    it "creates project and redirects" do
      expect {
        post projects_path, params: { project: { name: "My Project", description: "desc" } }
      }.to change(Project, :count).by(1)
      expect(response).to redirect_to(Project.order(:id).last)
    end

    it "renders new on invalid params" do
      post projects_path, params: { project: { name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /projects/:id/soft_delete
  # ---------------------------------------------------------------------------
  describe "PATCH /projects/:id/soft_delete" do
    it "archives the project" do
      patch soft_delete_project_path(project)
      expect(response).to redirect_to(projects_path)
      project.reload
      expect(project.deleted_at).not_to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /projects/:id/restore
  # ---------------------------------------------------------------------------
  describe "PATCH /projects/:id/restore" do
    before { project.soft_delete! }

    it "restores the project" do
      patch restore_project_path(project)
      expect(response).to redirect_to(archived_projects_path)
      project.reload
      expect(project.deleted_at).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # Access control: regular user cannot manage projects
  # ---------------------------------------------------------------------------
  describe "access control" do
    let(:regular_user) { create(:user) }

    before do
      Warden.test_reset!
      login_as regular_user, scope: :user
    end

    it "redirects non-admin away from project create" do
      post projects_path, params: { project: { name: "Hacked" } }
      expect(response).to redirect_to(root_path)
    end
  end
end
