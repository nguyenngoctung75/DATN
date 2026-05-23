class Project < ApplicationRecord
  include SoftDeletable
  include Loggable

  has_many :tasks, dependent: :destroy
  has_many :activity_logs, as: :trackable, dependent: :destroy
  has_many :daily_import_runs, dependent: :destroy
  has_many :import_runs, dependent: :destroy

  # Override soft_delete! to cascade to tasks
  def soft_delete!
    transaction do
      super
      tasks.active.update_all(deleted_at: deleted_at)
    end
  end

  # Override restore! to cascade to tasks
  def restore!
    transaction do
      tasks.where(deleted_at: deleted_at).update_all(deleted_at: nil)
      super
    end
  end

  validates :name, presence: true, length: { maximum: 50 }, uniqueness: { case_sensitive: false }

  # redmine_project_id (string, optional): Redmine project identifier for daily import.
  # When set and daily import is enabled, tasks are imported from this Redmine project into this local project.

  # Count tasks (excluding subtasks)
  def task_count
    root_tasks.count
  end

  def completed_task_count
    root_tasks.where(status: Task::COMPLETED_STATUSES).count
  end

  def root_tasks
    # A task is a root if it has no parent or its parent doesn't exist in the same project
    tasks.active.where('parent_id IS NULL OR parent_id NOT IN (SELECT id FROM tasks WHERE project_id = ?)', id)
  end

  def tasks_with_search(q: nil, status: nil, date_range: nil)
    scope = root_tasks.includes(:project, :assignee, :test_cases, :subtasks)
    scope = scope.where(created_at: date_range) if date_range
    if q.present?
      like_q = "%#{q.to_s.strip.downcase}%"
      scope = scope.where(
        'LOWER(tasks.title) LIKE :q OR CAST(tasks.id AS TEXT) LIKE :raw_q OR CAST(tasks.redmine_id AS TEXT) LIKE :raw_q',
        q: like_q, raw_q: "%#{q.to_s.strip}%"
      )
    end
    scope = scope.where('LOWER(status) = ?', status.to_s.downcase.tr('_', ' ')) if status.present?
    scope
  end

  def archived_root_tasks
    tasks.deleted
         .where('parent_id IS NULL OR parent_id NOT IN (SELECT id FROM tasks WHERE project_id = ?)', id)
         .includes(:project, :subtasks)
  end
end
