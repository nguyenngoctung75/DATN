class DatabaseBackupJob < ApplicationJob
  queue_as :default

  def perform
    db_config = ActiveRecord::Base.connection_db_config
    return unless db_config.adapter == 'sqlite3'

    db_path = db_config.database
    return unless File.exist?(db_path)
    backup_dir = Rails.root.join('storage', 'backups')
    FileUtils.mkdir_p(backup_dir)

    timestamp = Time.current.strftime('%Y-%m-%d_%H-%M-%S')
    file_name = File.basename(db_path)
    backup_path = backup_dir.join("#{file_name}.backup.#{timestamp}")

    require 'fileutils'
    FileUtils.cp(db_path, backup_path)

    # Optional: Nếu đang bật WAL thì cũng chép dự phòng file -wal để đảm bảo toàn vẹn nếu đang có transaction nóng
    wal_path = "#{db_path}-wal"
    FileUtils.cp(wal_path, "#{backup_path}-wal") if File.exist?(wal_path)

    Rails.logger.info("✅ Database backup created successfully at: #{backup_path}")

    # Tự động dọn dẹp: Chỉ giữ lại 7 bản backup gần nhất để tránh đầy ổ cứng
    cleanup_old_backups(backup_dir, file_name, keep: 7)
  end

  private

  def cleanup_old_backups(dir, base_name, keep:)
    # Lấy danh sách tất cả các bản backup của file này, sắp xếp theo thời gian (cũ nhất đứng đầu)
    backups = Dir.glob(dir.join("#{base_name}.backup.*")).reject { |f| f.end_with?("-wal") }.sort

    if backups.count > keep
      backups_to_delete = backups.first(backups.count - keep)
      backups_to_delete.each do |stale_backup|
        File.delete(stale_backup)
        # Đồng thời xoá file WAL đi kèm nếu có
        wal_stale_backup = "#{stale_backup}-wal"
        File.delete(wal_stale_backup) if File.exist?(wal_stale_backup)

        Rails.logger.info("🗑️ Deleted old backup: #{stale_backup}")
      end
    end
  end
end
