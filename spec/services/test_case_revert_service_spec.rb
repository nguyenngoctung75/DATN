require 'rails_helper'

RSpec.describe TestCaseRevertService do
  let(:project)   { create(:project) }
  let(:task)      { create(:task, project: project) }
  let(:test_case) { create(:test_case, task: task, note: 'current note') }

  def build_log(field:, old_value:, new_value:, trackable: test_case)
    ActivityLog.create!(
      user: create(:user),
      action_type: 'update',
      trackable: trackable,
      metadata: { field => [old_value, new_value] }
    )
  end

  describe '#call' do
    context 'when field is missing from metadata' do
      it 'returns failure with descriptive error' do
        log = ActivityLog.create!(
          user: create(:user), action_type: 'update',
          trackable: test_case, metadata: {}
        )
        result = described_class.new(activity_log: log, field: 'note').call
        expect(result.success?).to be false
        expect(result.error_message).to include('Could not find history data')
      end
    end

    context 'when field does not map to a column' do
      it 'returns failure with unsupported field message' do
        log = build_log(field: 'nonexistent_field', old_value: 'old', new_value: 'new')
        result = described_class.new(activity_log: log, field: 'nonexistent_field').call
        expect(result.success?).to be false
        expect(result.error_message).to include("Cannot revert 'nonexistent_field'")
      end
    end

    context 'when field maps to a valid column' do
      it 'updates the trackable and returns success with old value' do
        log = build_log(field: 'note', old_value: 'old note', new_value: 'current note')
        result = described_class.new(activity_log: log, field: 'note').call
        expect(result.success?).to be true
        expect(result.old_value).to eq('old note')
        expect(test_case.reload.note).to eq('old note')
      end
    end

    context 'when update fails validation' do
      it 'returns failure with model error messages' do
        log = build_log(field: 'title', old_value: '', new_value: 'current title')
        result = described_class.new(activity_log: log, field: 'title').call
        expect(result.success?).to be false
        expect(result.error_message).to include('Failed to revert')
      end
    end
  end
end
