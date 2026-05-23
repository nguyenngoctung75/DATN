require 'rails_helper'

RSpec.describe BugPresenter do
  let(:bug) { create(:bug, priority: 'high', status: 'fixing', category: 'stg_vn', bug_type: 'new_bug', application: 'sp_pc') }
  subject { described_class.new(bug) }

  describe '#priority_color' do
    it { expect(subject.priority_color).to eq('danger') }
    it { expect(described_class.new(create(:bug, priority: 'low')).priority_color).to eq('info') }
    it { expect(described_class.new(build_stubbed(:bug, priority: 'other')).priority_color).to eq('secondary') }
  end

  describe '#status_color' do
    it { expect(subject.status_color).to eq('warning') }
    it { expect(described_class.new(create(:bug, status: 'done')).status_color).to eq('success') }
  end

  describe '#category_display' do
    it { expect(subject.category_display).to eq('STG Bugs (VN)') }
    it { expect(described_class.new(create(:bug, category: 'prod')).category_display).to eq('Prod Bugs') }
  end

  describe '#bug_type_display' do
    it { expect(subject.bug_type_display).to eq('New Bug') }
  end

  describe '#bug_type_color' do
    it { expect(subject.bug_type_color).to eq('danger') }
    it { expect(described_class.new(create(:bug, bug_type: 'improve')).bug_type_color).to eq('info') }
  end

  describe '#application_display' do
    it { expect(subject.application_display).to eq('SP + PC') }
    it { expect(described_class.new(create(:bug, application: 'all')).application_display).to eq('SP + PC + APP') }
  end

  describe '#dev_name' do
    it 'returns associated user name when dev is set' do
      user = create(:user, name: 'Dev User')
      b = create(:bug, dev: user, dev_name_raw: 'raw dev')
      expect(described_class.new(b).dev_name).to eq('Dev User')
    end

    it 'falls back to dev_name_raw when no dev user' do
      b = create(:bug, dev: nil, dev_name_raw: 'raw dev')
      expect(described_class.new(b).dev_name).to eq('raw dev')
    end

    it 'returns N/A when neither dev nor raw name' do
      b = create(:bug, dev: nil, dev_name_raw: nil)
      expect(described_class.new(b).dev_name).to eq('N/A')
    end
  end

  describe '#tester_name' do
    it 'returns associated user name when tester is set' do
      user = create(:user, name: 'Tester User')
      b = create(:bug, tester: user, tester_name_raw: 'raw tester')
      expect(described_class.new(b).tester_name).to eq('Tester User')
    end

    it 'falls back to tester_name_raw when no tester user' do
      b = create(:bug, tester: nil, tester_name_raw: 'raw tester')
      expect(described_class.new(b).tester_name).to eq('raw tester')
    end
  end

  describe '#to_sheet_row' do
    it 'returns a hash with display values' do
      row = subject.to_sheet_row
      expect(row[:application]).to eq('SP + PC')
      expect(row[:category]).to eq('STG Bugs (VN)')
      expect(row[:dev]).to eq('N/A')
      expect(row[:tester]).to eq('N/A')
      expect(row[:no]).to eq(bug.id)
    end
  end

  it 'delegates model methods via SimpleDelegator' do
    expect(subject.title).to eq(bug.title)
    expect(subject.task_id).to eq(bug.task_id)
  end
end
