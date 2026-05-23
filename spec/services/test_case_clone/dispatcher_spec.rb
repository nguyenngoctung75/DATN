require 'rails_helper'

RSpec.describe TestCaseClone::Dispatcher do
  let(:user)        { create(:user) }
  let(:project)     { create(:project) }
  let(:source_task) { create(:task, project: project) }
  let(:dest_task)   { create(:task, project: project) }

  describe '#call' do
    context 'when destination task does not exist' do
      it 'returns failure' do
        result = described_class.new(
          source_task: source_task, source_ids: [], destination_task_id: 0,
          options: {}, user: user
        ).call
        expect(result.success?).to be false
        expect(result.error).to match(/Destination task not found/)
      end
    end

    context 'when destination is in a different project' do
      let(:other_project) { create(:project) }
      let(:other_dest)    { create(:task, project: other_project) }

      it 'rejects cross-project cloning' do
        create(:test_case, task: source_task)
        result = described_class.new(
          source_task: source_task, source_ids: [], destination_task_id: other_dest.id,
          options: {}, user: user
        ).call
        expect(result.success?).to be false
        expect(result.error).to match(/Cross-project/)
      end
    end

    context 'when destination is archived' do
      it 'returns failure' do
        dest_task.update!(deleted_at: Time.current)
        result = described_class.new(
          source_task: source_task, source_ids: [], destination_task_id: dest_task.id,
          options: {}, user: user
        ).call
        expect(result.success?).to be false
        expect(result.error).to match(/archived/)
      end
    end

    context 'when source is empty' do
      it 'returns failure with descriptive error' do
        result = described_class.new(
          source_task: source_task, source_ids: [], destination_task_id: dest_task.id,
          options: {}, user: user
        ).call
        expect(result.success?).to be false
        expect(result.error).to match(/No test cases/)
      end
    end

    context 'with batch size <= SYNC_THRESHOLD' do
      it 'runs synchronously and returns count' do
        create_list(:test_case, 3, task: source_task)
        result = described_class.new(
          source_task: source_task, source_ids: [], destination_task_id: dest_task.id,
          options: {}, user: user
        ).call
        expect(result.success?).to be true
        expect(result.async?).to be false
        expect(result.count).to eq(3)
      end
    end

    context 'with batch size > SYNC_THRESHOLD' do
      before { stub_const("#{described_class}::SYNC_THRESHOLD", 2) }

      it 'enqueues TestCaseCloneJob and returns async result' do
        create_list(:test_case, 3, task: source_task)
        expect {
          described_class.new(
            source_task: source_task, source_ids: [], destination_task_id: dest_task.id,
            options: {}, user: user
          ).call
        }.to have_enqueued_job(TestCaseCloneJob)
      end

      it 'creates an ImportRun with type clone_tc' do
        create_list(:test_case, 3, task: source_task)
        result = described_class.new(
          source_task: source_task, source_ids: [], destination_task_id: dest_task.id,
          options: {}, user: user
        ).call
        expect(result.async?).to be true
        expect(result.import_run.import_type).to eq('clone_tc')
        expect(result.import_run.total_count).to eq(3)
      end
    end
  end
end
