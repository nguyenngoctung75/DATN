require 'rails_helper'

RSpec.describe BugImportService do
  let(:project) { create(:project) }
  let(:task) do
    create(:task, project: project,
           bug_link: 'https://docs.google.com/spreadsheets/d/BUG_SHEET_ID/edit?gid=123456')
  end
  let(:google_service) { instance_double(GoogleSheetService) }
  let(:spreadsheet_id) { 'BUG_SHEET_ID' }

  before do
    allow(GoogleSheetService).to receive(:new).and_return(google_service)
  end

  describe '#import' do
    context 'when Google Sheet returns no sheets' do
      before do
        allow(google_service).to receive(:list_sheets).and_return([])
      end

      it 'returns false and records error' do
        service = described_class.new(task, spreadsheet_id)
        expect(service.import).to be false
        expect(service.errors).to include('Cannot get sheets info from Google Sheet')
      end
    end

    context 'when sheet data is fetched and rows processed' do
      let(:sheets_info) { [{ title: 'Bugs', sheet_id: '123456' }] }
      let(:header_row) { ['No', 'Title', 'Status', 'Category'] }
      let(:data_row)   { ['1', "Bug title\nfull content", 'new', 'stg_vn'] }
      let(:sheet_data) { [header_row, data_row] }

      let(:parser) { instance_double(BugImport::RowParser) }
      let(:mapper) { instance_double(BugImport::AttributeMapper) }

      before do
        allow(google_service).to receive(:list_sheets).and_return(sheets_info)
        allow(google_service).to receive(:fetch_sheet).with(name: 'Bugs').and_return(sheet_data)
        allow(BugImport::RowParser).to receive(:new).and_return(parser)
        allow(BugImport::AttributeMapper).to receive(:new).and_return(mapper)
        allow(parser).to receive(:parse_header).with(header_row).and_return({ content: 1, status: 2, category: 3 })
        allow(parser).to receive(:parse_row).and_return({ content: "Bug title\nfull content", status: 'new' })
        allow(mapper).to receive(:map).and_return({ status: 'new', category: 'stg_vn' })
      end

      it 'returns true' do
        service = described_class.new(task, spreadsheet_id)
        expect(service.import).to be true
      end
    end

    context 'when wipe_existing is true' do
      # task without gid in bug_link so sheets are not filtered by gid
      let(:task_no_gid) { create(:task, project: project, bug_link: 'https://docs.google.com/spreadsheets/d/BUG_SHEET_ID/edit') }
      let(:sheets_info) { [{ title: 'Bugs', sheet_id: nil }] }
      let(:parser) { instance_double(BugImport::RowParser) }
      let(:mapper) { instance_double(BugImport::AttributeMapper) }

      before do
        allow(google_service).to receive(:list_sheets).and_return(sheets_info)
        allow(google_service).to receive(:fetch_sheet).and_return([])
        allow(BugImport::RowParser).to receive(:new).and_return(parser)
        allow(BugImport::AttributeMapper).to receive(:new).and_return(mapper)
        create(:bug, task: task_no_gid)
      end

      it 'soft-deletes existing bugs before import' do
        service = described_class.new(task_no_gid, spreadsheet_id, wipe_existing: true)
        expect { service.import }.to change { task_no_gid.bugs.active.count }.from(1).to(0)
      end
    end

    context 'when an exception occurs during import' do
      before do
        allow(google_service).to receive(:list_sheets).and_raise(StandardError, 'API crash')
      end

      it 'returns false and records error' do
        service = described_class.new(task, spreadsheet_id)
        expect(service.import).to be false
        expect(service.errors.first).to include('Error importing bug')
      end
    end
  end
end
