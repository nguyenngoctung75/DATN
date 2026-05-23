require 'rails_helper'

RSpec.describe Task, type: :model do
  let(:project) { create(:project) }

  describe 'validations' do
    it 'requires title' do
      task = Task.new(project: project)
      expect(task).not_to be_valid
      expect(task.errors[:title]).to be_present
    end

    it 'validates due_date after start_date' do
      task = build(:task, project: project, start_date: Date.current, due_date: 1.day.ago.to_date)
      expect(task).not_to be_valid
      expect(task.errors[:due_date]).to be_present
    end

    it 'allows due_date equal to start_date' do
      today = Date.current
      task = build(:task, project: project, start_date: today, due_date: today)
      expect(task).to be_valid
    end
  end

  describe '#normalize_status (before_save)' do
    it 'downcases and strips status' do
      task = create(:task, project: project, status: '  In_Progress ')
      expect(task.reload.status).to eq('in progress')
    end

    it 'normalizes underscore to space' do
      task = create(:task, project: project, status: 'waiting_release')
      expect(task.reload.status).to eq('waiting release')
    end
  end

  describe '#progress_percentage' do
    it 'returns 0 when estimated_time is nil' do
      task = Task.new(estimated_time: nil, spent_time: 5)
      expect(task.progress_percentage).to eq(0)
    end

    it 'returns 0 when estimated_time is zero' do
      task = Task.new(estimated_time: 0, spent_time: 5)
      expect(task.progress_percentage).to eq(0)
    end

    it 'caps at 100' do
      task = Task.new(estimated_time: 2, spent_time: 10)
      expect(task.progress_percentage).to eq(100)
    end

    it 'computes correctly' do
      task = Task.new(estimated_time: 10, spent_time: 3)
      expect(task.progress_percentage).to eq(30.0)
    end
  end

  describe '#resolved?' do
    it 'returns true for completed statuses' do
      expect(Task.new(status: 'resolved').resolved?).to be true
      expect(Task.new(status: 'closed').resolved?).to be true
    end

    it 'returns false for open statuses' do
      expect(Task.new(status: 'new').resolved?).to be false
      expect(Task.new(status: 'in progress').resolved?).to be false
    end
  end

  describe '#overdue?' do
    it 'returns true when past due and not resolved' do
      task = Task.new(due_date: 1.day.ago.to_date, status: 'in progress')
      expect(task.overdue?).to be true
    end

    it 'returns false when resolved even if past due' do
      task = Task.new(due_date: 1.day.ago.to_date, status: 'resolved')
      expect(task.overdue?).to be false
    end

    it 'returns false when due_date is blank' do
      task = Task.new(due_date: nil, status: 'in progress')
      expect(task.overdue?).to be false
    end
  end

  describe '#root_task? / #subtask?' do
    it 'task with no parent and no redmine_id is root' do
      task = Task.new(parent_id: nil, redmine_id: nil)
      expect(task.root_task?).to be true
      expect(task.subtask?).to be false
    end

    it 'task with parent_id but no redmine_id is a subtask' do
      task = Task.new(parent_id: 1, redmine_id: nil)
      expect(task.root_task?).to be false
      expect(task.subtask?).to be true
    end
  end

  describe 'associations' do
    let!(:task) { create(:task, project: project) }

    it 'can have many test_cases' do
      tc1 = create(:test_case, task: task)
      tc2 = create(:test_case, task: task)
      expect(task.test_cases).to include(tc1, tc2)
    end

    it 'can have many bugs' do
      bug = create(:bug, task: task)
      expect(task.bugs).to include(bug)
    end

    it 'can have subtasks' do
      subtask = create(:task, project: project, parent_id: task.id)
      expect(task.subtasks).to include(subtask)
    end
  end
end
