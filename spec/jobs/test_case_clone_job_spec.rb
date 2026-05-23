require 'rails_helper'

RSpec.describe TestCaseCloneJob, type: :job do
  let(:user)        { create(:user) }
  let(:project)     { create(:project) }
  let(:source_task) { create(:task, project: project) }
  let(:dest_task)   { create(:task, project: project, title: 'Dest') }
  let!(:tc)         { create(:test_case, task: source_task) }

  let(:import_run) do
    ImportRun.create!(
      project: project, triggered_by: user, import_type: 'clone_tc', status: 'pending',
      total_count: 1,
      params: {
        'source_task_id' => source_task.id,
        'source_ids' => [ tc.id ],
        'destination_task_id' => dest_task.id,
        'options' => {}
      }
    )
  end

  it 'transitions ImportRun to success and stores imported_count' do
    described_class.perform_now(import_run.id)
    run = import_run.reload
    expect(run.status).to eq('success')
    expect(run.imported_count).to eq(1)
  end

  it 'creates an info Notification on success' do
    expect { described_class.perform_now(import_run.id) }
      .to change { Notification.where(category: 'info').count }.by(1)
  end

  it 'marks ImportRun failed and creates a warning Notification on service failure' do
    fake = instance_double(TestCaseClone::CloneService)
    allow(TestCaseClone::CloneService).to receive(:new).and_return(fake)
    allow(fake).to receive(:call).and_return(
      TestCaseClone::Result.failure(error: 'Disk full', import_run: import_run)
    )

    expect { described_class.perform_now(import_run.id) }
      .to change { Notification.where(category: 'warning').count }.by(1)

    run = import_run.reload
    expect(run.status).to eq('failed')
    expect(run.error_message).to include('Disk full')
  end

  it 'is idempotent if run already finished' do
    import_run.update_columns(status: 'success', finished_at: Time.current)
    expect { described_class.perform_now(import_run.id) }.not_to(change { dest_task.test_cases.count })
  end
end
