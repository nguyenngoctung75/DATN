require 'rails_helper'

RSpec.describe DailyImportJob, type: :job do
  let(:project) { create(:project, daily_import_enabled: true, redmine_project_id: 'test-project') }
  let(:importer) do
    instance_double(
      RedmineBulkImportService,
      import: true,
      imported_tasks: [],
      skipped_count: 0,
      found_count: 0,
      errors: []
    )
  end

  before do
    allow(RedmineBulkImportService).to receive(:new).and_return(importer)
  end

  describe '#perform' do
    context 'when global daily import is disabled' do
      before { ENV['DAILY_IMPORT_ENABLED'] = 'false' }
      after  { ENV.delete('DAILY_IMPORT_ENABLED') }

      it 'does not create any import run' do
        expect { described_class.perform_now }.not_to change(DailyImportRun, :count)
      end

      it 'does not create any notification' do
        expect { described_class.perform_now }.not_to change(Notification, :count)
      end
    end

    context 'when no projects have daily import enabled' do
      it 'does not create any import run' do
        expect { described_class.perform_now }.not_to change(DailyImportRun, :count)
      end
    end

    context 'when a project is configured for import' do
      before { project }

      context 'happy path: importer finds and imports tasks' do
        let(:imported_task) { create(:task, project: project) }

        before do
          allow(importer).to receive(:imported_tasks).and_return([imported_task])
          allow(importer).to receive(:skipped_count).and_return(0)
        end

        it 'creates a DailyImportRun with success status' do
          expect { described_class.perform_now }
            .to change(DailyImportRun, :count).by(1)
          expect(DailyImportRun.last.status).to eq('success')
        end

        it 'creates a cronjob notification' do
          expect { described_class.perform_now }
            .to change(Notification, :count).by(1)
          expect(Notification.last.category).to eq('cronjob')
        end
      end

      context 'when importer returns no new tasks' do
        before do
          allow(importer).to receive(:imported_tasks).and_return([])
          allow(importer).to receive(:found_count).and_return(0)
          allow(importer).to receive(:skipped_count).and_return(0)
        end

        it 'marks the run as skipped and notifies' do
          described_class.perform_now
          expect(DailyImportRun.last.status).to eq('skipped')
          expect(Notification.last.category).to eq('cronjob')
        end
      end

      context 'when importer fails' do
        before do
          allow(importer).to receive(:import).and_return(false)
          allow(importer).to receive(:errors).and_return(['service unavailable'])
        end

        it 'marks the run as failed' do
          described_class.perform_now
          expect(DailyImportRun.last.status).to eq('failed')
        end
      end

      context 'when an unexpected error is raised' do
        before { allow(importer).to receive(:import).and_raise(StandardError, 'network timeout') }

        it 'does not crash the job' do
          expect { described_class.perform_now }.not_to raise_error
        end

        it 'marks the run as failed with the error message' do
          described_class.perform_now
          expect(DailyImportRun.last.status).to eq('failed')
          expect(DailyImportRun.last.error_message).to include('network timeout')
        end
      end
    end
  end
end
