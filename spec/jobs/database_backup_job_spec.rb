require 'rails_helper'

RSpec.describe DatabaseBackupJob, type: :job do
  let(:tmpdir) { Dir.mktmpdir }

  before do
    allow(Rails).to receive(:root).and_return(Pathname.new(tmpdir))
  end

  after { FileUtils.rm_rf(tmpdir) }

  describe '#perform' do
    it 'creates a backup file in the backup directory' do
      described_class.perform_now
      backups = Dir.glob(File.join(tmpdir, 'storage', 'backups', '*'))
        .reject { |f| f.end_with?('-wal') }
      expect(backups).not_to be_empty
    end

    it 'keeps the backup directory structure' do
      described_class.perform_now
      expect(File.directory?(File.join(tmpdir, 'storage', 'backups'))).to be true
    end

    context 'when there are more than 7 existing backups' do
      let(:backup_dir) { File.join(tmpdir, 'storage', 'backups') }

      before do
        FileUtils.mkdir_p(backup_dir)
        db_config = ActiveRecord::Base.connection_db_config
        file_name = File.basename(db_config.database)
        9.times do |i|
          FileUtils.touch(File.join(backup_dir, "#{file_name}.backup.2024-01-0#{i + 1}_00-00-00"))
        end
      end

      it 'deletes the oldest backups, keeping only 7' do
        described_class.perform_now
        db_config = ActiveRecord::Base.connection_db_config
        file_name = File.basename(db_config.database)
        remaining = Dir.glob(File.join(backup_dir, "#{file_name}.backup.*"))
          .reject { |f| f.end_with?('-wal') }
        expect(remaining.count).to eq(7)
      end
    end
  end
end
