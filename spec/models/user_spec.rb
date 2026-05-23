require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      user = build(:user)
      expect(user).to be_valid
    end

    it 'requires email' do
      expect(build(:user, email: nil)).not_to be_valid
    end

    it 'requires email domain @example.com' do
      expect(build(:user, email: 'user@gmail.com')).not_to be_valid
    end

    it 'requires unique email' do
      create(:user, email: 'dup@example.com')
      expect(build(:user, email: 'dup@example.com')).not_to be_valid
    end

    it 'requires provider' do
      expect(build(:user, provider: nil)).not_to be_valid
    end
  end

  describe 'role enum' do
    it 'defaults to user role' do
      user = create(:user)
      expect(user).to be_user
      expect(user).not_to be_admin
    end

    it 'can be admin' do
      user = create(:user, :admin)
      expect(user).to be_admin
    end
  end

  describe 'SoftDeletable' do
    let(:user) { create(:user) }

    it 'soft_delete! sets deleted_at' do
      user.soft_delete!
      expect(user.deleted_at).not_to be_nil
    end

    it '.active scope excludes soft-deleted' do
      user.soft_delete!
      expect(User.active).not_to include(user)
    end

    it '.deleted scope includes soft-deleted' do
      user.soft_delete!
      expect(User.deleted).to include(user)
    end
  end

  describe 'associations' do
    it 'can have assigned tasks' do
      user = create(:user)
      project = create(:project)
      task = create(:task, project: project, assignee: user)
      expect(user.assigned_tasks).to include(task)
    end
  end
end
