require 'rails_helper'

RSpec.describe TestCaseClone::CloneService do
  let(:user)        { create(:user) }
  let(:project)     { create(:project) }
  let(:source_task) { create(:task, project: project, title: 'Source Task') }
  let(:dest_task)   { create(:task, project: project, title: 'Destination Task') }

  def build_full_test_case(task, title: 'TC1')
    tc = create(:test_case, task: task, title: title, description: 'desc', note: 'a note')
    step = TestStep.create!(test_case: tc, step_number: 1, description: 'do it')
    TestStepContent.create!(test_step: step, content_type: 'text', content_value: 'click button',
                             content_category: 'action', display_order: 0)
    TestStepContent.create!(test_step: step, content_type: 'text', content_value: 'see result',
                             content_category: 'expectation', display_order: 0)
    tc
  end

  describe '#call' do
    context 'with valid sources' do
      let!(:tc1) { build_full_test_case(source_task, title: 'TC1') }
      let!(:tc2) { build_full_test_case(source_task, title: 'TC2') }

      it 'returns a successful Result with cloned IDs' do
        result = described_class.new(
          source_test_cases: source_task.test_cases.where(id: [ tc1.id, tc2.id ]),
          destination_task: dest_task,
          options: {},
          user: user
        ).call

        expect(result.success?).to be true
        expect(result.count).to eq(2)
        expect(result.ids.size).to eq(2)
      end

      it 'deep-copies test_steps and test_step_contents' do
        described_class.new(
          source_test_cases: source_task.test_cases.where(id: tc1.id),
          destination_task: dest_task, options: {}, user: user
        ).call

        clone = dest_task.test_cases.last
        expect(clone.test_steps.count).to eq(1)
        expect(clone.test_steps.first.test_step_contents.count).to eq(2)
        expect(clone.test_steps.first.id).not_to eq(tc1.test_step.id)
      end

      it 'does not copy test_results' do
        TestResult.create!(test_case: tc1, status: 'pass', device: 'pc')
        described_class.new(
          source_test_cases: source_task.test_cases.where(id: tc1.id),
          destination_task: dest_task, options: {}, user: user
        ).call
        clone = dest_task.test_cases.last
        expect(clone.test_results.count).to eq(0)
      end

      it 'assigns sequential positions in destination' do
        existing = create(:test_case, task: dest_task, title: 'Existing')
        existing.update!(position: 7)

        described_class.new(
          source_test_cases: source_task.test_cases.where(id: [ tc1.id, tc2.id ]),
          destination_task: dest_task, options: {}, user: user
        ).call

        positions = dest_task.test_cases.where(title: %w[TC1 TC2]).pluck(:position).sort
        expect(positions).to eq([ 8, 9 ])
      end

      it 'updates destination task counter' do
        expect {
          described_class.new(
            source_test_cases: source_task.test_cases.where(id: [ tc1.id, tc2.id ]),
            destination_task: dest_task, options: {}, user: user
          ).call
        }.to change { dest_task.reload.number_of_test_cases }.by(2)
      end

      it 'records the cloning user as created_by on the new test cases' do
        described_class.new(
          source_test_cases: source_task.test_cases.where(id: tc1.id),
          destination_task: dest_task, options: {}, user: user
        ).call
        clone = dest_task.test_cases.last
        expect(clone.created_by_id).to eq(user.id)
      end
    end

    context 'when cloning into the same task' do
      let!(:tc) { build_full_test_case(source_task, title: 'Same') }

      it 'auto-appends "(copy)" to title to avoid sync_grouped_titles trigger' do
        described_class.new(
          source_test_cases: source_task.test_cases.where(id: tc.id),
          destination_task: source_task, options: {}, user: user
        ).call
        titles = source_task.test_cases.pluck(:title)
        expect(titles).to include('Same (copy)')
      end
    end

    context 'when append_copy_suffix option is true' do
      let!(:tc) { build_full_test_case(source_task, title: 'Original') }

      it 'appends "(copy)" even on cross-task clone' do
        described_class.new(
          source_test_cases: source_task.test_cases.where(id: tc.id),
          destination_task: dest_task,
          options: { append_copy_suffix: true }, user: user
        ).call
        expect(dest_task.test_cases.last.title).to eq('Original (copy)')
      end
    end

    context 'when source relation is empty' do
      it 'returns success with count 0' do
        result = described_class.new(
          source_test_cases: source_task.test_cases.none,
          destination_task: dest_task, options: {}, user: user
        ).call

        expect(result.success?).to be true
        expect(result.count).to eq(0)
      end
    end

    context 'when an error is raised mid-batch' do
      let!(:tc1) { build_full_test_case(source_task, title: 'OK') }
      let!(:tc2) { build_full_test_case(source_task, title: 'Bad') }

      it 'rolls back the entire batch (transaction integrity)' do
        call_count = 0
        original = TestStepContent.method(:insert_all)
        allow(TestStepContent).to receive(:insert_all) do |args|
          call_count += 1
          raise ActiveRecord::StatementInvalid, 'boom' if call_count == 2

          original.call(args)
        end

        expect {
          described_class.new(
            source_test_cases: source_task.test_cases.where(id: [ tc1.id, tc2.id ]),
            destination_task: dest_task, options: {}, user: user
          ).call
        }.not_to change { dest_task.test_cases.count }
      end

      it 'returns a failure Result' do
        allow(TestStepContent).to receive(:insert_all).and_raise(ActiveRecord::StatementInvalid, 'boom')
        result = described_class.new(
          source_test_cases: source_task.test_cases.where(id: tc1.id),
          destination_task: dest_task, options: {}, user: user
        ).call
        expect(result.success?).to be false
        expect(result.error).to include('boom')
      end
    end
  end
end
