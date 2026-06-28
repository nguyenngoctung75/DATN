require 'rails_helper'

RSpec.describe TestCase, type: :model do
  let(:project) { create(:project) }
  let(:task) { create(:task, project: project) }

  describe 'validations' do
    it 'requires title' do
      tc = TestCase.new(task: task, title: nil)
      expect(tc).not_to be_valid
      expect(tc.errors[:title]).to be_present
    end

    it 'requires task_id' do
      tc = TestCase.new(title: 'TC', task_id: nil)
      expect(tc).not_to be_valid
    end

    it 'strips leading/trailing whitespace from title before validation' do
      tc = create(:test_case, task: task, title: '  My Test  ')
      expect(tc.title).to eq('My Test')
    end
  end

  describe 'task counter update' do
    it 'increments task.number_of_test_cases on create' do
      expect { create(:test_case, task: task) }
        .to change { task.reload.number_of_test_cases }.by(1)
    end

    it 'decrements task.number_of_test_cases on destroy' do
      tc = create(:test_case, task: task)
      expect { tc.destroy }.to change { task.reload.number_of_test_cases }.by(-1)
    end

    it 'updates both old and new task counters when moved' do
      other_task = create(:task, project: project)
      tc = create(:test_case, task: task)
      expect(task.reload.number_of_test_cases).to eq(1)

      tc.update!(task: other_task)

      expect(task.reload.number_of_test_cases).to eq(0)
      expect(other_task.reload.number_of_test_cases).to eq(1)
    end
  end

  describe '#device_match?' do
    subject(:tc) { TestCase.new }

    it 'matches pc category to desktop browser names' do
      expect(tc.send(:device_match?, 'Chrome PC', 'pc')).to be true
      expect(tc.send(:device_match?, 'iPhone 13', 'pc')).to be false
    end

    it 'matches sp category to mobile device names' do
      expect(tc.send(:device_match?, 'iPhone 13', 'sp')).to be true
      expect(tc.send(:device_match?, 'Chrome PC', 'sp')).to be false
    end

    it 'returns false for blank device_name' do
      expect(tc.send(:device_match?, '', 'pc')).to be false
      expect(tc.send(:device_match?, nil, 'sp')).to be false
    end

    it 'falls back to exact match for unknown category' do
      expect(tc.send(:device_match?, 'custom', 'custom')).to be true
      expect(tc.send(:device_match?, 'other', 'custom')).to be false
    end
  end

  describe 'SoftDeletable' do
    let!(:tc) { create(:test_case, task: task) }

    it '.active excludes soft-deleted test cases' do
      tc.soft_delete!
      expect(TestCase.active).not_to include(tc)
    end

    it 'deleted? is true after soft_delete!' do
      tc.soft_delete!
      expect(tc.reload.deleted?).to be true
    end
  end

  describe '#step_count' do
    it 'returns number of test steps' do
      tc = create(:test_case, task: task)
      expect(tc.step_count).to eq(0)
    end
  end

  describe 'destroy cascade' do
    it 'destroys dependent test steps and their step contents' do
      tc = create(:test_case, task: task)
      step = tc.test_steps.create!(step_number: 1)
      step.test_step_contents.create!(content_type: 'text', content_value: 'do something')

      expect { tc.destroy }
        .to change { TestStep.where(case_id: tc.id).count }.from(1).to(0)
        .and change { TestStepContent.where(step_id: step.id).count }.from(1).to(0)
    end
  end
end
