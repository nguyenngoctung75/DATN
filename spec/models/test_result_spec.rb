require 'rails_helper'

RSpec.describe TestResult, type: :model do
  describe 'validations' do
    let(:test_case) { create(:test_case) }

    it 'is valid with valid attributes' do
      expect(build(:test_result, case_id: test_case.id)).to be_valid
    end

    it 'requires case_id' do
      expect(build(:test_result, case_id: nil)).not_to be_valid
    end

    it 'requires status' do
      expect(build(:test_result, case_id: test_case.id, status: nil)).not_to be_valid
    end

    it 'validates status inclusion' do
      expect(build(:test_result, case_id: test_case.id, status: 'invalid')).not_to be_valid
    end

    it 'accepts all valid statuses' do
      TestResult::ALL_STATUSES.each do |s|
        expect(build(:test_result, case_id: test_case.id, status: s)).to be_valid
      end
    end
  end

  describe 'scopes' do
    let!(:active_result) { create(:test_result) }
    let!(:deleted_result) { create(:test_result).tap(&:soft_delete!) }

    it '.active excludes soft-deleted' do
      expect(TestResult.active).to include(active_result)
      expect(TestResult.active).not_to include(deleted_result)
    end

    it '.deleted includes only soft-deleted' do
      expect(TestResult.deleted).to include(deleted_result)
      expect(TestResult.deleted).not_to include(active_result)
    end

    it '.by_status filters by status' do
      pass_result = create(:test_result, status: 'pass')
      fail_result = create(:test_result, status: 'fail')
      expect(TestResult.by_status('pass')).to include(pass_result)
      expect(TestResult.by_status('pass')).not_to include(fail_result)
    end
  end

  describe '#soft_delete!' do
    it 'sets deleted_at' do
      tr = create(:test_result)
      tr.soft_delete!
      expect(tr.deleted_at).not_to be_nil
    end
  end

  describe '#active?' do
    it 'returns true when not deleted' do
      expect(build(:test_result).active?).to be true
    end

    it 'returns false when deleted' do
      tr = create(:test_result)
      tr.soft_delete!
      expect(tr.active?).to be false
    end
  end

  describe 'no orphan association to TestEnvironment' do
    it 'does not respond to test_environment' do
      expect(TestResult.new).not_to respond_to(:test_environment)
    end
  end
end
