require 'rails_helper'

RSpec.describe RedmineImportJob, type: :job do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:import_run) do
    ImportRun.create!(
      project: project,
      triggered_by: user,
      import_type: 'redmine_url',
      status: 'pending',
      params: { 'issue_id' => '123' }
    )
  end
  let(:task) { create(:task, project: project, title: 'Issue 123', number_of_test_cases: 7) }
  let(:service) { instance_double(RedmineImportService, import: true, task: task, errors: []) }

  before { allow(RedmineImportService).to receive(:new).and_return(service) }

  it 'transitions ImportRun from pending to running to success' do
    described_class.perform_now(import_run.id)
    run = import_run.reload
    expect(run.status).to eq('success')
    expect(run.imported_count).to eq(7)
    expect(run.finished_at).to be_present
  end

  it 'creates an info Notification on success' do
    expect { described_class.perform_now(import_run.id) }
      .to change(Notification, :count).by(1)
    expect(Notification.order(:id).last.category).to eq('info')
  end

  it 'marks ImportRun failed when service returns false' do
    allow(service).to receive(:import).and_return(false)
    allow(service).to receive(:errors).and_return(['Could not find issue'])

    described_class.perform_now(import_run.id)
    run = import_run.reload
    expect(run.status).to eq('failed')
    expect(run.error_message).to include('Could not find issue')
  end

  it 'creates a warning Notification when service fails' do
    allow(service).to receive(:import).and_return(false)
    allow(service).to receive(:errors).and_return(['Could not find issue'])

    expect { described_class.perform_now(import_run.id) }
      .to change { Notification.where(category: 'warning').count }.by(1)
  end

  it 'marks ImportRun failed on exception and re-raises' do
    allow(service).to receive(:import).and_raise(StandardError, 'network timeout')

    expect { described_class.perform_now(import_run.id) }
      .to raise_error(StandardError, 'network timeout')
    run = import_run.reload
    expect(run.status).to eq('failed')
    expect(run.error_message).to include('network timeout')
  end

  it 'creates a warning Notification on exception' do
    allow(service).to receive(:import).and_raise(StandardError, 'crash')

    expect {
      begin
        described_class.perform_now(import_run.id)
      rescue StandardError
        # expected
      end
    }.to change { Notification.where(category: 'warning').count }.by(1)
  end
end
