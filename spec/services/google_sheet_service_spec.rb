require 'rails_helper'

RSpec.describe GoogleSheetService do
  let(:spreadsheet_id) { 'FAKE_SPREADSHEET_ID' }
  let(:sheets_service) { instance_double(Google::Apis::SheetsV4::SheetsService) }

  before do
    allow(Google::Apis::SheetsV4::SheetsService).to receive(:new).and_return(sheets_service)
    allow(sheets_service).to receive(:authorization=)
    # Stub credential loading so tests don't require a real credentials file
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?)
      .with(Rails.root.join('config', 'google_credentials.json'))
      .and_return(true)
    fake_creds = instance_double(Google::Auth::ServiceAccountCredentials)
    allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds).and_return(fake_creds)
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read)
      .with(Rails.root.join('config', 'google_credentials.json'))
      .and_return('{}')
  end

  describe '#list_sheets' do
    it 'returns an array of sheet title and id hashes' do
      sheet_props = instance_double(Google::Apis::SheetsV4::SheetProperties, title: 'Sheet1', sheet_id: 0)
      sheet       = instance_double(Google::Apis::SheetsV4::Sheet, properties: sheet_props)
      spreadsheet = instance_double(Google::Apis::SheetsV4::Spreadsheet, sheets: [sheet])
      allow(sheets_service).to receive(:get_spreadsheet).and_return(spreadsheet)

      result = described_class.new(spreadsheet_id).list_sheets
      expect(result).to eq([{ title: 'Sheet1', sheet_id: '0' }])
    end

    it 'returns empty array when API call fails' do
      allow(sheets_service).to receive(:get_spreadsheet).and_return(nil)
      result = described_class.new(spreadsheet_id).list_sheets
      expect(result).to eq([])
    end
  end

  describe '#fetch_sheet' do
    it 'returns row arrays when API responds' do
      rows = [['Header1', 'Header2'], ['val1', 'val2']]
      response = instance_double(Google::Apis::SheetsV4::ValueRange, values: rows)
      allow(sheets_service).to receive(:get_spreadsheet_values).and_return(response)

      result = described_class.new(spreadsheet_id).fetch_sheet(name: 'Sheet1')
      expect(result).to eq(rows)
    end

    it 'returns empty array when API returns no values' do
      response = instance_double(Google::Apis::SheetsV4::ValueRange, values: nil)
      allow(sheets_service).to receive(:get_spreadsheet_values).and_return(response)

      result = described_class.new(spreadsheet_id).fetch_sheet(name: 'Sheet1')
      expect(result).to eq([])
    end

    it 'returns nil when API raises a Google error' do
      allow(sheets_service).to receive(:get_spreadsheet_values)
        .and_raise(Google::Apis::Error.new('quota'))

      result = described_class.new(spreadsheet_id).fetch_sheet(name: 'Sheet1')
      expect(result).to be_nil
    end
  end
end
