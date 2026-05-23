require 'rails_helper'

RSpec.describe DailyImportOrchestrator do
  let(:project) { create(:project, redmine_project_id: 42) }
  subject(:orchestrator) { described_class.new(project) }

  let(:fake_importer) do
    instance_double(
      RedmineBulkImportService,
      import: true,
      imported_tasks: [],
      found_count: 0,
      skipped_count: 0,
      errors: []
    )
  end

  before do
    allow(RedmineBulkImportService).to receive(:new).and_return(fake_importer)
    allow(fake_importer).to receive(:import).and_yield(0).and_return(true)
    allow(Notify).to receive(:cronjob)
  end

  describe '#run' do
    it 'creates a DailyImportRun record with running status' do
      expect { orchestrator.run }.to change(DailyImportRun, :count).by(1)
      run = DailyImportRun.last
      expect(run.project).to eq(project)
    end

    it 'returns self for chaining' do
      expect(orchestrator.run).to eq(orchestrator)
    end

    context 'when import succeeds with no new tasks' do
      it 'marks run as skipped' do
        orchestrator.run
        expect(DailyImportRun.last.status).to eq('skipped')
      end

      it 'sends cronjob notification' do
        orchestrator.run
        expect(Notify).to have_received(:cronjob).with(hash_including(title: "Daily Import: #{project.name}"))
      end
    end

    context 'when import succeeds with new tasks' do
      let(:imported_task) { create(:task, project: project) }

      before do
        allow(fake_importer).to receive(:imported_tasks).and_return([imported_task])
        allow(fake_importer).to receive(:import).and_yield(1).and_return(true)
      end

      it 'marks run as success and sets imported_count' do
        orchestrator.run
        run = DailyImportRun.last
        expect(run.status).to eq('success')
        expect(run.imported_count).to eq(1)
      end

      it 'populates imported_count on orchestrator' do
        orchestrator.run
        expect(orchestrator.imported_count).to eq(1)
      end
    end

    context 'when import fails' do
      before do
        allow(fake_importer).to receive(:import).and_return(false)
        allow(fake_importer).to receive(:errors).and_return(['Redmine unreachable'])
      end

      it 'marks run as failed' do
        orchestrator.run
        expect(DailyImportRun.last.status).to eq('failed')
      end

      it 'records errors on orchestrator' do
        orchestrator.run
        expect(orchestrator.errors).to include('Redmine unreachable')
      end
    end

    context 'when an unexpected exception is raised' do
      before do
        allow(RedmineBulkImportService).to receive(:new).and_raise(RuntimeError, 'unexpected boom')
      end

      it 'marks run as failed without raising' do
        expect { orchestrator.run }.not_to raise_error
        expect(DailyImportRun.last.status).to eq('failed')
      end

      it 'stores the error message' do
        orchestrator.run
        expect(orchestrator.errors).to include('unexpected boom')
      end
    end
  end
end
