require 'rails_helper'

RSpec.describe Project, type: :model do
  describe 'validations' do
    it 'requires name' do
      project = Project.new
      expect(project).not_to be_valid
      expect(project.errors[:name]).to be_present
    end

    it 'enforces name uniqueness (case-insensitive)' do
      create(:project, name: 'Alpha')
      dup = build(:project, name: 'alpha')
      expect(dup).not_to be_valid
      expect(dup.errors[:name]).to be_present
    end

    it 'enforces name max length of 50' do
      project = build(:project, name: 'A' * 51)
      expect(project).not_to be_valid
    end
  end

  describe 'SoftDeletable cascade' do
    let!(:project) { create(:project) }
    let!(:task1)   { create(:task, project: project) }
    let!(:task2)   { create(:task, project: project) }

    it 'soft_delete! archives the project' do
      project.soft_delete!
      expect(project.reload.deleted?).to be true
    end

    it 'soft_delete! cascades to active tasks' do
      project.soft_delete!
      expect(task1.reload.deleted_at).not_to be_nil
      expect(task2.reload.deleted_at).not_to be_nil
    end

    it 'restore! unarchives the project' do
      project.soft_delete!
      project.restore!
      expect(project.reload.deleted?).to be false
    end

    it 'restore! restores tasks that were archived at the same time' do
      project.soft_delete!
      project.restore!
      expect(task1.reload.deleted_at).to be_nil
      expect(task2.reload.deleted_at).to be_nil
    end

    it 'restore! does not touch tasks deleted independently before project archive' do
      task1.soft_delete!
      sleep(0.01) # ensure different deleted_at timestamp
      project.soft_delete!
      project.restore!
      # task1 had a different deleted_at, so it should remain deleted
      expect(task1.reload.deleted_at).not_to be_nil
    end
  end

  describe '#task_count' do
    let!(:project) { create(:project) }

    it 'counts only root tasks' do
      root = create(:task, project: project, parent_id: nil, redmine_id: nil)
      _sub = create(:task, project: project, parent_id: root.id)
      expect(project.task_count).to eq(1)
    end

    it 'excludes archived tasks' do
      task = create(:task, project: project)
      task.soft_delete!
      expect(project.task_count).to eq(0)
    end
  end
end
