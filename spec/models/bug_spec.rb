require 'rails_helper'

RSpec.describe Bug, type: :model do
  let(:project) { create(:project) }
  let(:task) { create(:task, project: project) }

  describe 'validations' do
    it 'requires title' do
      bug = Bug.new(task: task, category: 'ui', priority: 'medium', status: 'new')
      bug.title = nil
      expect(bug).not_to be_valid
      expect(bug.errors[:title]).to be_present
    end

    it 'requires category' do
      bug = Bug.new(task: task, title: 'Bug', priority: 'medium', status: 'new')
      bug.category = nil
      expect(bug).not_to be_valid
    end

    it 'requires priority' do
      bug = Bug.new(task: task, title: 'Bug', category: 'ui', status: 'new')
      bug.priority = nil
      expect(bug).not_to be_valid
    end

    it 'requires status' do
      bug = Bug.new(task: task, title: 'Bug', category: 'ui', priority: 'medium')
      bug.status = nil
      expect(bug).not_to be_valid
    end
  end

  describe 'STATUSES constant' do
    it 'contains canonical values' do
      expect(Bug::STATUSES).to eq(%w[new fixing testing pending done])
    end
  end

  describe 'scopes' do
    let!(:open_bug)   { create(:bug, task: task, status: 'new') }
    let!(:fixing_bug) { create(:bug, task: task, status: 'fixing') }
    let!(:done_bug)   { create(:bug, task: task, status: 'done') }

    it '.open returns non-done bugs' do
      expect(Bug.open).to include(open_bug, fixing_bug)
      expect(Bug.open).not_to include(done_bug)
    end

    it '.closed returns only done bugs' do
      expect(Bug.closed).to contain_exactly(done_bug)
    end
  end

  describe '#open? / #closed?' do
    it 'open? is true for non-done statuses' do
      expect(Bug.new(status: 'fixing').open?).to be true
      expect(Bug.new(status: 'done').open?).to be false
    end

    it 'closed? is true only for done' do
      expect(Bug.new(status: 'done').closed?).to be true
      expect(Bug.new(status: 'new').closed?).to be false
    end
  end

  describe 'display methods (via BugPresenter)' do
    it 'priority_color maps high to danger' do
      expect(BugPresenter.new(Bug.new(priority: 'high')).priority_color).to eq('danger')
    end

    it 'priority_color returns secondary for unknown priority' do
      expect(BugPresenter.new(Bug.new(priority: 'unknown')).priority_color).to eq('secondary')
    end

    it 'status_color maps known statuses to colors' do
      expect(BugPresenter.new(Bug.new(status: 'new')).status_color).to eq('primary')
      expect(BugPresenter.new(Bug.new(status: 'done')).status_color).to eq('success')
    end
  end

  describe 'SoftDeletable' do
    let!(:bug) { create(:bug, task: task) }

    it 'soft_delete! sets deleted_at' do
      bug.soft_delete!
      expect(bug.reload.deleted_at).not_to be_nil
    end

    it 'restore! clears deleted_at' do
      bug.update!(deleted_at: Time.current)
      bug.restore!
      expect(bug.reload.deleted_at).to be_nil
    end

    it '.active scope excludes soft-deleted' do
      bug.soft_delete!
      expect(Bug.active).not_to include(bug)
    end

    it '.deleted scope includes soft-deleted' do
      bug.soft_delete!
      expect(Bug.deleted).to include(bug)
    end
  end
end
