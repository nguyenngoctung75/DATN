require 'rails_helper'

RSpec.describe RedmineBulkImportJob, type: :job do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:import_run) do
    ImportRun.create!(
      project: project, triggered_by: user, import_type: 'redmine_bulk', status: 'pending',
      params: { 'issue_ids' => %w[101 102] }
    )
  end
  let(:imported_task) { create(:task, project: project) }
  let(:service) do
    instance_double(
      RedmineBulkImportService,
      import_by_issue_ids: true,
      import_all: true,
      imported_tasks: [ imported_task ],
      skipped_count: 1,
      found_count: 2,
      errors: []
    )
  end

  before do
    allow(RedmineBulkImportService).to receive(:new).and_return(service)
  end

  it 'transitions ImportRun to success and stores counts' do
    described_class.perform_now(import_run.id)
    run = import_run.reload
    expect(run.status).to eq('success')
    expect(run.imported_count).to eq(1)
    expect(run.skipped_count).to eq(1)
  end

  it 'creates an info Notification on success' do
    expect { described_class.perform_now(import_run.id) }
      .to change { Notification.where(category: 'info').count }.by(1)
  end

  it 'marks ImportRun failed when service returns errors and zero imports' do
    allow(service).to receive(:import_by_issue_ids).and_return(false)
    allow(service).to receive(:imported_tasks).and_return([])
    allow(service).to receive(:errors).and_return([ 'Network down' ])

    described_class.perform_now(import_run.id)
    run = import_run.reload
    expect(run.status).to eq('failed')
    expect(run.error_message).to include('Network down')
  end
end
