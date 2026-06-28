require "rails_helper"

RSpec.describe ActivityTimelinePresenter do
  let(:user) { create(:user) }
  let(:task) { create(:task) }

  def build_log(metadata, action: "update")
    ActivityLog.create!(user: user, trackable: task, action_type: action, metadata: metadata)
  end

  it "shows description changes" do
    log = build_log({ "description" => [ "old", "new" ] })
    presenter = described_class.new([ log ])
    expect(presenter.total_count).to eq(1)
    expect(presenter.entries.first.changes.map(&:label)).to include("Description")
  end

  it "shows test_phase changes (a non-status field)" do
    log = build_log({ "test_phase" => [ "not_started", "executing" ] })
    expect(described_class.new([ log ]).total_count).to eq(1)
  end

  it "shows testcase_link changes" do
    log = build_log({ "testcase_link" => [ "", "https://sheet" ] })
    expect(described_class.new([ log ]).total_count).to eq(1)
  end

  it "ignores internal counter fields" do
    log = build_log({ "number_of_test_cases" => [ 1, 2 ] })
    expect(described_class.new([ log ]).total_count).to eq(0)
  end

  it "ignores no-op changes" do
    log = build_log({ "status" => [ "new", "new" ] })
    expect(described_class.new([ log ]).total_count).to eq(0)
  end
end
