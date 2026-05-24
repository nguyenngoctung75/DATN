require 'rails_helper'

RSpec.describe TestRun, type: :model do
  let(:project) { create(:project) }
  let(:task) { create(:task, project: project) }

  describe 'validations' do
    it 'requires name' do
      run = TestRun.new(task: task, status: 'pending')
      run.name = nil
      expect(run).not_to be_valid
      expect(run.errors[:name]).to be_present
    end

    it 'requires task_id' do
      run = TestRun.new(name: 'Run 1', status: 'pending')
      expect(run).not_to be_valid
    end

    it 'rejects invalid status' do
      run = TestRun.new(name: 'Run 1', task: task, status: 'bogus')
      expect(run).not_to be_valid
      expect(run.errors[:status]).to be_present
    end

    it 'accepts valid statuses' do
      TestRun::STATUSES.each do |s|
        run = TestRun.new(name: 'Run', task: task, status: s)
        expect(run.errors[:status]).to be_empty
      end
    end
  end

  describe 'STATUSES constant' do
    it 'defines canonical status values' do
      expect(TestRun::STATUSES).to eq(%w[pending running completed aborted])
    end

    it 'defines IN_PROGRESS_STATUSES subset' do
      expect(TestRun::IN_PROGRESS_STATUSES).to eq(%w[pending running])
    end

    it 'defines FINISHED_STATUSES subset' do
      expect(TestRun::FINISHED_STATUSES).to eq(%w[completed aborted])
    end
  end

  describe 'status predicate methods' do
    it '#in_progress? returns true for pending/running' do
      expect(TestRun.new(status: 'pending').in_progress?).to be true
      expect(TestRun.new(status: 'running').in_progress?).to be true
      expect(TestRun.new(status: 'completed').in_progress?).to be false
    end

    it '#finished? returns true for completed/aborted' do
      expect(TestRun.new(status: 'completed').finished?).to be true
      expect(TestRun.new(status: 'aborted').finished?).to be true
      expect(TestRun.new(status: 'running').finished?).to be false
    end
  end

  describe '#pass_rate' do
    let(:run) { TestRun.new }

    it 'returns 0 when no results' do
      allow(run).to receive(:pass_count).and_return(0)
      allow(run).to receive(:fail_count).and_return(0)
      allow(run).to receive(:not_run_count).and_return(0)
      expect(run.pass_rate).to eq(0)
    end

    it 'computes correctly' do
      allow(run).to receive(:pass_count).and_return(7)
      allow(run).to receive(:fail_count).and_return(2)
      allow(run).to receive(:not_run_count).and_return(1)
      expect(run.pass_rate).to eq(70.0)
    end
  end

  describe 'state transitions' do
    let!(:run) { TestRun.create!(name: 'Run', task: task, status: 'pending') }

    it '#start! transitions to running' do
      run.start!
      expect(run.reload.status).to eq('running')
      expect(run.started_at).not_to be_nil
    end

    it '#complete! transitions to completed' do
      run.start!
      run.complete!
      expect(run.reload.status).to eq('completed')
      expect(run.completed_at).not_to be_nil
    end

    it '#abort! transitions to aborted' do
      run.start!
      run.abort!
      expect(run.reload.status).to eq('aborted')
    end
  end

  describe '#soft_delete!' do
    let!(:run) { TestRun.create!(name: 'Run', task: task, status: 'pending') }

    it 'sets deleted_at' do
      run.soft_delete!
      expect(run.reload.deleted_at).not_to be_nil
    end

    it 'is excluded from .active scope' do
      run.soft_delete!
      expect(TestRun.active).not_to include(run)
    end
  end
end
