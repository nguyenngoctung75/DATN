require 'rails_helper'

RSpec.describe TestCaseImportService do
  let(:project) { create(:project) }
  let(:task) do
    create(:task, project: project,
           testcase_link: 'https://docs.google.com/spreadsheets/d/TC_SHEET/edit')
  end
  let(:spreadsheet_id) { 'TC_SHEET' }
  let(:google_service) { instance_double(GoogleSheetService) }

  before { allow(GoogleSheetService).to receive(:new).and_return(google_service) }

  describe '#import' do
    context 'when no sheets are available' do
      before { allow(google_service).to receive(:list_sheets).and_return([]) }

      it 'returns false and records error' do
        service = described_class.new(task, spreadsheet_id)
        expect(service.import).to be false
        expect(service.errors).to include('Cannot get data from Google Sheet')
      end
    end

    context 'when sheets are present but empty' do
      before do
        allow(google_service).to receive(:list_sheets).and_return([{ title: 'Sheet1' }])
        allow(google_service).to receive(:fetch_sheet).and_return(nil)
      end

      it 'returns true with 0 imported' do
        service = described_class.new(task, spreadsheet_id)
        expect(service.import).to be true
        expect(service.imported_count).to eq(0)
      end
    end

    context 'with sheet_name_filter and no matching sheet' do
      before do
        allow(google_service).to receive(:list_sheets).and_return([{ title: 'Sheet1' }])
      end

      it 'returns false with no-match error' do
        service = described_class.new(task, spreadsheet_id, sheet_name_filter: 'Nonexistent')
        expect(service.import).to be false
        expect(service.errors.first).to include("No sheet matching '#Nonexistent' found")
      end
    end

    context 'when wipe_existing destroys existing test cases' do
      before do
        allow(google_service).to receive(:list_sheets).and_return([{ title: 'Sheet1' }])
        allow(google_service).to receive(:fetch_sheet).and_return([])
        create(:test_case, task: task)
      end

      it 'removes existing test cases before import' do
        service = described_class.new(task, spreadsheet_id, wipe_existing: true)
        expect { service.import }.to change { task.test_cases.count }.from(1).to(0)
      end
    end

    context 'when an unexpected exception occurs' do
      before do
        allow(google_service).to receive(:list_sheets).and_raise(StandardError, 'exploded')
      end

      it 'returns false and records error' do
        service = described_class.new(task, spreadsheet_id)
        expect(service.import).to be false
        expect(service.errors.first).to include('Import error')
      end
    end
  end
end
