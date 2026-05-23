require 'rails_helper'

RSpec.describe ManualImportJob, type: :job do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:task) { create(:task, project: project, testcase_link: 'https://docs.google.com/spreadsheets/d/abc/edit') }
  let(:import_run) do
    ImportRun.create!(
      project: project, triggered_by: user, import_type: 'manual', status: 'pending',
      params: { 'task_id' => task.id }
    )
  end
  let(:orchestrator) { instance_double(ManualImportOrchestrator, run: nil, tc_count: 3, bug_count: 0) }

  before do
    allow(ManualImportOrchestrator).to receive(:new).and_return(orchestrator)
    allow(orchestrator).to receive(:run).and_return(orchestrator)
  end

  it 'transitions ImportRun to running then success' do
    described_class.perform_now(import_run.id)
    expect(import_run.reload.status).to eq('success')
    expect(import_run.imported_count).to eq(3)
    expect(import_run.finished_at).to be_present
  end

  it 'creates a Notification with category info' do
    expect { described_class.perform_now(import_run.id) }
      .to change(Notification, :count).by(1)
    notif = Notification.order(:id).last
    expect(notif.category).to eq('info')
    expect(notif.title).to include('Import done')
  end

  it 'marks ImportRun failed on exception and re-raises' do
    allow(orchestrator).to receive(:run).and_raise(StandardError, 'boom')
    expect { described_class.perform_now(import_run.id) }.to raise_error(StandardError, 'boom')
    expect(import_run.reload.status).to eq('failed')
    expect(import_run.error_message).to include('boom')
  end

  it 'creates a warning Notification when import fails' do
    allow(orchestrator).to receive(:run).and_raise(StandardError, 'boom')
    expect {
      begin
        described_class.perform_now(import_run.id)
      rescue StandardError
        # expected
      end
    }.to change { Notification.where(category: 'warning').count }.by(1)
  end
end
