require 'rails_helper'

RSpec.describe Redmine::ImportOrchestrator do
  let(:project) { create(:project) }
  let(:issue_data) do
    {
      'id' => '123',
      'subject' => 'Test Task',
      'description' => 'Desc',
      'status' => { 'name' => 'In Progress' },
      'estimated_hours' => nil,
      'spent_hours' => nil,
      'done_ratio' => 0,
      'start_date' => nil,
      'due_date' => nil,
      'custom_fields' => []
    }
  end

  describe '#import' do
    context 'when Fetcher returns nil (invalid ID)' do
      let(:fetcher) { instance_double(Redmine::Fetcher, call: nil, error: 'Invalid issue ID') }

      before { allow(Redmine::Fetcher).to receive(:new).and_return(fetcher) }

      it 'returns false and captures fetcher error' do
        orchestrator = described_class.new('abc', project.id)
        expect(orchestrator.import).to be false
        expect(orchestrator.errors).to include('Invalid issue ID')
      end
    end

    context 'when Fetcher returns issue data' do
      let(:task) { create(:task, project: project, title: 'Test Task') }
      let(:fetcher) { instance_double(Redmine::Fetcher, call: issue_data) }
      let(:creator) { instance_double(Redmine::TaskCreator, create_or_update: task, errors: []) }
      let(:importer) { instance_double(Redmine::SubtaskImporter, run: nil, errors: []) }

      before do
        allow(Redmine::Fetcher).to receive(:new).and_return(fetcher)
        allow(Redmine::TaskCreator).to receive(:new).and_return(creator)
        allow(Redmine::SubtaskImporter).to receive(:new).and_return(importer)
      end

      it 'returns true and sets task' do
        orchestrator = described_class.new('123', project.id)
        expect(orchestrator.import).to be true
        expect(orchestrator.task).to eq(task)
        expect(orchestrator.errors).to be_empty
      end
    end

    context 'when an exception occurs' do
      before do
        allow(Redmine::Fetcher).to receive(:new).and_raise(StandardError, 'network error')
      end

      it 'returns false and records error' do
        orchestrator = described_class.new('123', project.id)
        expect(orchestrator.import).to be false
        expect(orchestrator.errors.first).to include('Error importing task')
      end
    end
  end

  describe '#import_from_issue_data' do
    let(:task) { create(:task, project: project, title: 'Test Task') }
    let(:creator) { instance_double(Redmine::TaskCreator, create_or_update: task, errors: []) }
    let(:importer) { instance_double(Redmine::SubtaskImporter, run: nil, errors: []) }

    before do
      allow(Redmine::TaskCreator).to receive(:new).and_return(creator)
      allow(Redmine::SubtaskImporter).to receive(:new).and_return(importer)
    end

    it 'creates task and runs subtask importer, returns true' do
      orchestrator = described_class.new('123', project.id)
      expect(orchestrator.import_from_issue_data(issue_data)).to be true
      expect(orchestrator.task).to eq(task)
    end

    it 'collects errors from creator and importer' do
      allow(creator).to receive(:errors).and_return(['creator error'])
      allow(importer).to receive(:errors).and_return(['importer error'])
      orchestrator = described_class.new('123', project.id)
      orchestrator.import_from_issue_data(issue_data)
      expect(orchestrator.errors).to include('creator error', 'importer error')
    end
  end
end
