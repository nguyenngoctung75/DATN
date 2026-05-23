require 'rails_helper'

RSpec.describe ManualImportOrchestrator do
  let(:project) { create(:project) }
  let(:task) { create(:task, project: project, testcase_link: nil, bug_link: nil) }

  describe '#run' do
    context 'when task has no links' do
      it 'returns self with zero counts' do
        result = described_class.new(task).run
        expect(result.tc_count).to eq(0)
        expect(result.bug_count).to eq(0)
      end
    end

    context 'when task has a testcase_link' do
      let(:task_with_link) do
        create(:task, project: project,
               testcase_link: 'https://docs.google.com/spreadsheets/d/SHEET_ID_TC/edit',
               bug_link: nil)
      end
      let(:tc_service) { instance_double(TestCaseImportService, import: true, imported_count: 5) }

      before do
        allow(TestCaseImportService).to receive(:new).and_return(tc_service)
      end

      it 'calls TestCaseImportService and captures tc_count' do
        result = described_class.new(task_with_link).run
        expect(result.tc_count).to eq(5)
        expect(result.bug_count).to eq(0)
      end
    end

    context 'when task has both testcase_link and bug_link' do
      let(:task_with_links) do
        create(:task, project: project,
               testcase_link: 'https://docs.google.com/spreadsheets/d/TC_ID/edit',
               bug_link: 'https://docs.google.com/spreadsheets/d/BUG_ID/edit')
      end
      let(:tc_service)  { instance_double(TestCaseImportService, import: true, imported_count: 3) }
      let(:bug_service) { instance_double(BugImportService, import: true, imported_count: 2) }

      before do
        allow(TestCaseImportService).to receive(:new).and_return(tc_service)
        allow(BugImportService).to receive(:new).and_return(bug_service)
      end

      it 'imports both and captures both counts' do
        result = described_class.new(task_with_links).run
        expect(result.tc_count).to eq(3)
        expect(result.bug_count).to eq(2)
      end

      it 'updates import_run progress twice when import_run provided' do
        import_run = ImportRun.create!(
          project: project, import_type: 'manual', status: 'running', total_count: 2
        )
        described_class.new(task_with_links, import_run: import_run).run
        expect(import_run.reload.processed_count).to eq(2)
      end
    end
  end
end
