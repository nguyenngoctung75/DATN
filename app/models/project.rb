class Project < ApplicationRecord
  include SoftDeletable
  include Loggable

  DEVELOPMENT_STATUSES = %w[planning in_development testing released maintenance].freeze

  has_many :tasks, dependent: :destroy
  has_many :activity_logs, as: :trackable, dependent: :destroy
  has_many :daily_import_runs, dependent: :destroy
  has_many :import_runs, dependent: :destroy

  has_many :project_users, dependent: :destroy
  has_many :users, through: :project_users

  def soft_delete!
    transaction do
      super
      tasks.active.update_all(deleted_at: deleted_at)
    end
  end

  def restore!
    transaction do
      tasks.where(deleted_at: deleted_at).update_all(deleted_at: nil)
      super
    end
  end

  validates :name, presence: true, length: { maximum: 50 }, uniqueness: { case_sensitive: false }
  validates :development_status, inclusion: { in: DEVELOPMENT_STATUSES, allow_blank: true }

  def task_count
    root_tasks.count
  end

  def completed_task_count
    root_tasks.where(status: Task::COMPLETED_STATUSES).count
  end

  def root_tasks
    tasks.active.where('parent_id IS NULL OR parent_id NOT IN (SELECT id FROM tasks WHERE project_id = ?)', id)
  end

  def tasks_with_search(q: nil, status: nil, date_range: nil, created_by: nil, assignee_id: nil)
    scope = root_tasks.includes(:project, :assignee, :test_cases, :subtasks)
    scope = scope.where(created_at: date_range) if date_range
    if q.present?
      like_q = "%#{q.to_s.strip.downcase}%"
      scope = scope.where(
        'LOWER(tasks.title) LIKE :q OR CAST(tasks.id AS CHAR) LIKE :raw_q ' \
          'OR CAST(tasks.redmine_id AS CHAR) LIKE :raw_q',
        q: like_q, raw_q: "%#{q.to_s.strip}%"
      )
    end
    if status.present?
      scope = scope.where('LOWER(status) = ?', status.to_s.downcase.tr('_', ' '))
    else
      scope = scope.where("status IS NULL OR LOWER(status) <> 'closed'")
    end
    scope = scope.where(created_by_name: created_by) if created_by.present?
    scope = scope.where(assignee_id: assignee_id) if assignee_id.present?
    scope
  end

  def archived_root_tasks
    tasks.deleted
         .where('parent_id IS NULL OR parent_id NOT IN (SELECT id FROM tasks WHERE project_id = ?)', id)
         .includes(:project, :subtasks)
  end

  def task_status_counts
    counts = root_tasks.group(:status).count
    Task::STATUSES.index_with { |status| counts[status] || 0 }
  end

  def accessible_to?(user)
    return false if user.nil?
    return true if user.admin?

    open_to_all_users || project_users.exists?(user_id: user.id)
  end
end
