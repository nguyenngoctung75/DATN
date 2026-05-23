require 'rails_helper'

RSpec.describe ImportRun, type: :model do
  let(:project) { create(:project) }
  let(:user) { create(:user) }

  describe 'validations' do
    it 'requires a valid status' do
      run = ImportRun.new(project: project, import_type: 'manual', status: 'bogus')
      expect(run).not_to be_valid
      expect(run.errors[:status]).to be_present
    end

    it 'requires a valid import_type' do
      run = ImportRun.new(project: project, import_type: 'bogus', status: 'pending')
      expect(run).not_to be_valid
      expect(run.errors[:import_type]).to be_present
    end
  end

  describe '#params=' do
    it 'serializes a hash into params_json' do
      run = ImportRun.new(project: project, import_type: 'manual')
      run.params = { 'task_id' => 7 }
      expect(run.params_json).to eq('{"task_id":7}')
    end
  end

  describe '#params' do
    it 'returns {} when params_json blank' do
      run = ImportRun.new
      expect(run.params).to eq({})
    end

    it 'parses JSON safely' do
      run = ImportRun.new(params_json: '{"a":1}')
      expect(run.params).to eq('a' => 1)
    end

    it 'returns {} on malformed JSON' do
      run = ImportRun.new(params_json: 'not-json')
      expect(run.params).to eq({})
    end
  end

  describe '#progress_percent' do
    it 'returns 0 when total_count is 0' do
      run = ImportRun.new(processed_count: 5, total_count: 0)
      expect(run.progress_percent).to eq(0)
    end

    it 'caps at 100' do
      run = ImportRun.new(processed_count: 50, total_count: 10)
      expect(run.progress_percent).to eq(100)
    end

    it 'computes correctly' do
      run = ImportRun.new(processed_count: 3, total_count: 10)
      expect(run.progress_percent).to eq(30)
    end
  end

  describe '#increment_progress!' do
    it 'increments processed_count atomically' do
      run = ImportRun.create!(project: project, triggered_by: user, import_type: 'manual',
                              status: 'running', total_count: 5)
      run.increment_progress!
      run.increment_progress!
      expect(run.reload.processed_count).to eq(2)
    end
  end

  describe '#broadcast_progress' do
    it 'broadcasts to triggered_by user via UserChannel' do
      run = ImportRun.create!(project: project, triggered_by: user, import_type: 'manual',
                              status: 'running', total_count: 4, processed_count: 2)
      expect { run.broadcast_progress }
        .to have_broadcasted_to(user)
        .from_channel(UserChannel)
        .with(hash_including(event: 'import_progress', import_run_id: run.id, progress_percent: 50))
    end

    it 'no-ops when triggered_by is nil' do
      run = ImportRun.create!(project: project, import_type: 'manual', status: 'running')
      expect { run.broadcast_progress }.not_to raise_error
    end
  end
end
