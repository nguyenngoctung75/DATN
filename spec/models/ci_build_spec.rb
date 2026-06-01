require 'rails_helper'

RSpec.describe CiBuild, type: :model do
  describe 'validations' do
    it 'is valid with required attributes from factory' do
      expect(build(:ci_build)).to be_valid
    end

    %i[commit_sha branch status workflow_run_id].each do |attr|
      it "requires #{attr}" do
        record = build(:ci_build, attr => nil)
        expect(record).not_to be_valid
        expect(record.errors[attr]).to be_present
      end
    end

    it 'enforces uniqueness of workflow_run_id' do
      create(:ci_build, workflow_run_id: 'dup-1')
      record = build(:ci_build, workflow_run_id: 'dup-1')
      expect(record).not_to be_valid
      expect(record.errors[:workflow_run_id]).to be_present
    end

    %w[success failed not_run].each do |valid_status|
      it "accepts status=#{valid_status}" do
        expect(build(:ci_build, status: valid_status)).to be_valid
      end
    end

    it 'rejects unknown status' do
      record = build(:ci_build, status: 'broken')
      expect(record).not_to be_valid
      expect(record.errors[:status]).to be_present
    end
  end

  describe 'associations' do
    it 'belongs to task optionally' do
      record = build(:ci_build, task: nil)
      expect(record).to be_valid
    end

    it 'can be linked to a task' do
      task = create(:task)
      record = create(:ci_build, task: task)
      expect(record.task).to eq(task)
    end
  end

  describe '#short_sha' do
    it 'returns first 7 chars' do
      record = build(:ci_build, commit_sha: 'abcdef1234567890')
      expect(record.short_sha).to eq('abcdef1')
    end
  end

  describe 'state helpers' do
    it '#succeeded? true only when status=success' do
      expect(build(:ci_build, status: 'success').succeeded?).to be true
      expect(build(:ci_build, status: 'failed').succeeded?).to be false
      expect(build(:ci_build, status: 'not_run').succeeded?).to be false
    end

    it '#failed? true only when status=failed' do
      expect(build(:ci_build, status: 'failed').failed?).to be true
      expect(build(:ci_build, status: 'success').failed?).to be false
    end

    it '#not_run? true only when status=not_run' do
      expect(build(:ci_build, status: 'not_run').not_run?).to be true
      expect(build(:ci_build, status: 'failed').not_run?).to be false
    end
  end

  describe '.recent' do
    it 'orders by created_at desc' do
      old = create(:ci_build, created_at: 2.days.ago)
      new = create(:ci_build, created_at: 1.hour.ago)
      expect(CiBuild.recent.to_a.first(2)).to eq([new, old])
    end
  end
end
