require 'rails_helper'
require 'cancan/matchers'

RSpec.describe Ability, type: :model do
  subject(:ability) { described_class.new(user) }

  describe 'admin role' do
    let(:user) { build(:user, :admin) }

    it 'can manage everything' do
      expect(ability).to be_able_to(:manage, :all)
    end
  end

  describe 'user role' do
    let(:user) { build(:user) }

    it 'can read projects, tasks, test cases, bugs' do
      expect(ability).to be_able_to(:read, Project)
      expect(ability).to be_able_to(:read, Task)
      expect(ability).to be_able_to(:read, TestCase)
      expect(ability).to be_able_to(:read, Bug)
    end

    it 'can read test runs and test results' do
      expect(ability).to be_able_to(:read, TestRun)
      expect(ability).to be_able_to(:read, TestResult)
    end

    it 'can create and update test cases' do
      expect(ability).to be_able_to(:create, TestCase)
      expect(ability).to be_able_to(:update, TestCase)
    end

    it 'can create and update bugs' do
      expect(ability).to be_able_to(:create, Bug)
      expect(ability).to be_able_to(:update, Bug)
    end

    it 'can create and destroy test steps' do
      expect(ability).to be_able_to(:create, TestStep)
      expect(ability).to be_able_to(:destroy, TestStep)
    end

    it 'can start, complete, and abort test runs' do
      expect(ability).to be_able_to(:start, TestRun)
      expect(ability).to be_able_to(:complete, TestRun)
      expect(ability).to be_able_to(:abort, TestRun)
    end

    it 'can view history of test cases and bugs' do
      expect(ability).to be_able_to(:history, TestCase)
      expect(ability).to be_able_to(:history, Bug)
    end

    it 'cannot destroy users or projects' do
      expect(ability).not_to be_able_to(:destroy, User)
      expect(ability).not_to be_able_to(:destroy, Project)
    end

    it 'can manage tasks (create/update/delete)' do
      expect(ability).to be_able_to(:create, Task)
      expect(ability).to be_able_to(:update, Task)
      expect(ability).to be_able_to(:destroy, Task)
    end

    it 'cannot see cronjob notifications' do
      cronjob_notif = build(:notification, category: 'cronjob')
      expect(ability).not_to be_able_to(:read, cronjob_notif)
    end

    it 'can read non-cronjob notifications' do
      info_notif = build(:notification, category: 'info')
      expect(ability).to be_able_to(:read, info_notif)
    end
  end

  describe 'nil user (unauthenticated)' do
    let(:user) { nil }

    # nil → User.new with default role :user; Devise's authenticate_user! is the primary guard
    it 'gets user-level read permissions via User.new default role' do
      expect(ability).to be_able_to(:read, Project)
      expect(ability).not_to be_able_to(:manage, Project)
    end
  end
end
