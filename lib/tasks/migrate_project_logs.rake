namespace :activity_logs do
  desc 'Create activity logs for existing projects'
  task populate_project_logs: :environment do
    puts 'Creating activity logs for existing projects...'

    Project.find_each do |project|
      # Tạo log 'create' cho mỗi project
      existing_log = ActivityLog.find_by(
        trackable_type: 'Project',
        trackable_id: project.id,
        action_type: 'create'
      )

      next if existing_log # Bỏ qua nếu đã có log

      ActivityLog.create!(
        user_id: 1, # Admin user (hoặc có thể lấy user thực tế)
        trackable_type: 'Project',
        trackable_id: project.id,
        action_type: 'create',
        metadata: {
          'name' => [ nil, project.name ],
          'description' => [ nil, project.description ]
        },
        created_at: project.created_at,
        updated_at: project.created_at
      )

      puts "✓ Created log for project: #{project.name}"

      # Nếu project đã bị soft delete, tạo thêm log 'delete'
      if project.deleted_at.present?
        ActivityLog.create!(
          user_id: 1,
          trackable_type: 'Project',
          trackable_id: project.id,
          action_type: 'delete',
          metadata: {
            'deleted_at' => [ nil, project.deleted_at ]
          },
          created_at: project.deleted_at,
          updated_at: project.deleted_at
        )
        puts '  ✓ Created delete log for archived project'
      end
    end

    total_logs = ActivityLog.where(trackable_type: 'Project').count
    puts "\nDone! Total Project ActivityLogs: #{total_logs}"
  end
end
