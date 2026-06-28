require "rails_helper"

RSpec.describe AiGenerateTcJob, type: :job do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:task) { create(:task, project: project) }
  let(:import_run) do
    ImportRun.create!(
      project: project, triggered_by: user, import_type: "ai_generate_tc", status: "pending",
      params: { "task_id" => task.id, "description" => "Login feature" }
    )
  end
  let(:result) { AiTestCaseGenerationService::Result.new(imported_count: 3, skipped_count: 1, errors: []) }
  let(:service) { instance_double(AiTestCaseGenerationService, generate!: result) }

  before { allow(AiTestCaseGenerationService).to receive(:new).and_return(service) }

  it "transitions ImportRun to success with counts" do
    described_class.perform_now(import_run.id)
    expect(import_run.reload.status).to eq("success")
    expect(import_run.imported_count).to eq(3)
    expect(import_run.skipped_count).to eq(1)
    expect(import_run.finished_at).to be_present
  end

  it "creates an info Notification on success" do
    expect { described_class.perform_now(import_run.id) }
      .to change { Notification.where(category: "info").count }.by(1)
  end

  it "marks ImportRun failed and re-raises on error" do
    allow(service).to receive(:generate!).and_raise(StandardError, "boom")
    expect { described_class.perform_now(import_run.id) }.to raise_error(StandardError, "boom")
    expect(import_run.reload.status).to eq("failed")
    expect(import_run.error_message).to include("boom")
  end

  it "creates a warning Notification on failure" do
    allow(service).to receive(:generate!).and_raise(StandardError, "boom")
    expect {
      begin
        described_class.perform_now(import_run.id)
      rescue StandardError
        # expected
      end
    }.to change { Notification.where(category: "warning").count }.by(1)
  end
end
