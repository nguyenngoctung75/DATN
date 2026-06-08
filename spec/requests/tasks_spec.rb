require "rails_helper"

RSpec.describe "Tasks", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project) }
  let!(:task) { create(:task, project: project, status: "new") }

  before { login_as admin, scope: :user }

  # ---------------------------------------------------------------------------
  # GET /tasks (standalone index, no project scope)
  # ---------------------------------------------------------------------------
  describe "GET /tasks" do
    it "returns 200" do
      get tasks_path
      expect(response).to have_http_status(:ok)
    end

    it "filters by status (case-insensitive, underscore-tolerant)" do
      create(:task, project: project, status: "in progress")
      get tasks_path, params: { status: "in_progress" }
      expect(response).to have_http_status(:ok)
    end

    it "filters by search query matching title" do
      create(:task, project: project, title: "Login feature")
      get tasks_path, params: { q: "Login" }
      expect(response).to have_http_status(:ok)
    end

    it "paginates and clamps page to valid range" do
      get tasks_path, params: { page: 999 }
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /projects/:project_id/tasks (scoped to project)
  # ---------------------------------------------------------------------------
  describe "GET /projects/:project_id/tasks" do
    it "returns tasks for the project" do
      get project_tasks_path(project)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /projects/:project_id/tasks/:id (show)
  # ---------------------------------------------------------------------------
  describe "GET /projects/:project_id/tasks/:id" do
    it "returns 200 HTML" do
      get project_task_path(project, task)
      expect(response).to have_http_status(:ok)
    end

    it "returns JSON when requested" do
      get project_task_path(project, task, format: :json)
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body).to include("id" => task.id, "title" => task.title)
    end

    it "uses asc sort by default" do
      get project_task_path(project, task, params: { tc_sort: "asc" })
      expect(response).to have_http_status(:ok)
    end

    it "clamps tc_page within valid range" do
      get project_task_path(project, task, params: { tc_page: 999 })
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /projects/:project_id/tasks/:id/promote_to_subtask
  # ---------------------------------------------------------------------------
  describe "POST /projects/:project_id/tasks/:id/promote_to_subtask" do
    let!(:tc) { create(:test_case, task: task, title: "Login") }

    it "creates a subtask and moves matching test cases by title" do
      expect {
        post promote_to_subtask_project_task_path(project, task), params: { function: "Login" }
      }.to change(Task, :count).by(1)

      subtask = Task.order(:id).last
      expect(subtask.parent_id).to eq(task.id)
      expect(subtask.title).to include("Login")
      tc.reload
      expect(tc.task_id).to eq(subtask.id)
    end

    it "redirects with alert when function param is blank" do
      post promote_to_subtask_project_task_path(project, task), params: { function: "" }
      expect(response).to redirect_to(project_task_path(project, task))
      expect(flash[:alert]).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # POST /projects/:project_id/tasks/:id/promote_all_to_subtask
  # ---------------------------------------------------------------------------
  describe "POST /projects/:project_id/tasks/:id/promote_all_to_subtask" do
    let!(:tc1) { create(:test_case, task: task) }
    let!(:tc2) { create(:test_case, task: task) }

    it "moves all active test cases to a new subtask" do
      expect {
        post promote_all_to_subtask_project_task_path(project, task)
      }.to change(Task, :count).by(1)

      subtask = Task.order(:id).last
      expect(subtask.parent_id).to eq(task.id)
      [tc1, tc2].each do |tc|
        tc.reload
        expect(tc.task_id).to eq(subtask.id)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /projects/:project_id/tasks/new
  # ---------------------------------------------------------------------------
  describe "GET /projects/:project_id/tasks/new" do
    it "returns 200" do
      get new_project_task_path(project)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /projects/:project_id/tasks (create)
  # ---------------------------------------------------------------------------
  describe "POST /projects/:project_id/tasks" do
    let(:valid_params) { { task: { title: "New Task", status: "new" } } }
    let(:invalid_params) { { task: { title: "" } } }

    it "creates a task and redirects" do
      expect {
        post project_tasks_path(project), params: valid_params
      }.to change(Task, :count).by(1)
      expect(response).to redirect_to(project_task_path(project, Task.order(:id).last))
    end

    it "renders new on invalid params" do
      post project_tasks_path(project), params: invalid_params
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
