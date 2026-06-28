require "rails_helper"

RSpec.describe "Project membership authorization", type: :request do
  let(:user) { create(:user) }
  let!(:member_project) { create(:project, name: "Member Project") }
  let!(:other_project) { create(:project, name: "Other Project") }

  before do
    allow(RedmineService).to receive(:get_projects_list).and_return([])
    member_project.users << user
    login_as user, scope: :user
  end

  describe "GET /projects (index)" do
    it "lists only projects the user is assigned to" do
      get projects_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Member Project")
      expect(response.body).not_to include("Other Project")
    end

    it "includes projects open to all users" do
      other_project.update!(open_to_all_users: true)
      get projects_path
      expect(response.body).to include("Other Project")
    end
  end

  describe "GET /projects/:id (show)" do
    it "allows an assigned member" do
      get project_path(member_project)
      expect(response).to have_http_status(:ok)
    end

    it "denies a non-member" do
      get project_path(other_project)
      expect(response).to redirect_to(root_path)
    end

    it "allows any user when the project is open to all" do
      other_project.update!(open_to_all_users: true)
      get project_path(other_project)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "task access under a non-member project" do
    let!(:task) { create(:task, project: other_project) }

    it "denies viewing a task in a project the user is not assigned to" do
      get project_task_path(other_project, task)
      expect(response).to redirect_to(root_path)
    end

    it "allows viewing a task in an assigned project" do
      member_task = create(:task, project: member_project)
      get project_task_path(member_project, member_task)
      expect(response).to have_http_status(:ok)
    end
  end
end
