require "rails_helper"

RSpec.describe "Project management update", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:member) { create(:user) }
  let!(:project) { create(:project) }

  before do
    allow(RedmineService).to receive(:get_projects_list).and_return([])
    login_as admin, scope: :user
  end

  it "saves members, product info, test plan and parsed schedule" do
    patch project_path(project), params: {
      project: {
        name: project.name,
        open_to_all_users: "1",
        user_ids: [ member.id ],
        product_version: "v2.0.1",
        development_status: "testing",
        product_info: { owner: "Alice", progress: "70", tech_stack: "Rails, Hotwire" },
        test_plan: { objective: "Verify auth flow", scope: "Login, logout" }
      },
      schedule_text: "Test design | 2026-07-01\nExecution | 2026-07-10"
    }

    expect(response).to redirect_to(project)
    project.reload
    expect(project.open_to_all_users).to be(true)
    expect(project.user_ids).to include(member.id)
    expect(project.product_version).to eq("v2.0.1")
    expect(project.development_status).to eq("testing")
    expect(project.product_info["owner"]).to eq("Alice")
    expect(project.test_plan["objective"]).to eq("Verify auth flow")
    expect(project.test_plan["schedule"]).to eq(
      [
        { "milestone" => "Test design", "date" => "2026-07-01" },
        { "milestone" => "Execution", "date" => "2026-07-10" }
      ]
    )
  end
end
