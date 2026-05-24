class Task < ApplicationRecord
  include SoftDeletable
  include Loggable

  STATUSES = [
    'new',
    'pending',
    'in progress',
    'resolved',
    'waiting release',
    'closed'
  ].freeze
  COMPLETED_STATUSES = %w[resolved closed].freeze

  belongs_to :project
  belongs_to :assignee, class_name: 'User', foreign_key: 'assignee_id', optional: true
  belongs_to :parent, class_name: 'Task', foreign_key: 'parent_id', counter_cache: :subtasks_count, optional: true

  has_many :subtasks, class_name: 'Task', foreign_key: 'parent_id', dependent: :destroy
  has_many :test_cases, dependent: :destroy
  has_many :test_runs, dependent: :destroy
  has_many :bugs, dependent: :destroy

  validates :title, presence: true
  validates :status, inclusion: { in: STATUSES, allow_nil: true }
  validates :estimated_time, :spent_time, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :percent_done, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100, allow_nil: true }
  validate :due_date_after_start_date
  before_validation :normalize_status

  private

  def normalize_status
    return if status.blank?

    normalized = status.to_s.downcase.tr('_', ' ').squeeze(' ').strip
    self.status = STATUSES.include?(normalized) ? normalized : nil
  end

  def due_date_after_start_date
    return if due_date.blank? || start_date.blank?

    return unless due_date < start_date

    errors.add(:due_date, 'must be greater than or equal to the start date')
  end

  public

  scope :root_tasks, lambda {
    where(parent_id: nil, redmine_id: nil)
      .or(where.not(parent_id: nil).where.not(redmine_id: nil))
  }

  scope :search, ->(q) {
    where(
      'tasks.title LIKE :q OR tasks.description LIKE :q OR CAST(tasks.redmine_id AS CHAR) LIKE :q',
      q: "%#{q}%"
    )
  }
  scope :with_status, ->(s) { where(status: s.to_s.downcase.tr('_', ' ')) }

  SORT_DIRECTIONS = { 'asc' => 'ASC', 'desc' => 'DESC' }.freeze

  def test_cases_ordered(sort: 'asc', show_archived: false)
    tc_sort = SORT_DIRECTIONS[sort] || 'ASC'
    query = test_cases.includes(:test_steps, :test_results)
    query = show_archived ? query.deleted : query.active
    query.order(Arel.sql("COALESCE(test_cases.position, test_cases.id) #{tc_sort}"))
  end

  def promote_to_subtask!(function_name, project:, created_by_name:)
    subtask = nil
    count = 0
    ApplicationRecord.transaction do
      subtask = subtasks.create!(
        project: project,
        title: "#{title} - #{function_name}".truncate(255),
        status: 'new',
        created_by_name: created_by_name
      )
      tcs = test_cases.where(title: function_name)
      count = tcs.count
      tcs.update_all(task_id: subtask.id)
      update_column(:number_of_test_cases, test_cases.active.count)
      subtask.update_column(:number_of_test_cases, subtask.test_cases.active.count)
    end
    [ subtask, count ]
  rescue ActiveRecord::RecordInvalid
    [ nil, 0 ]
  end

  def promote_all_to_subtask!(project:, created_by_name:)
    subtask = nil
    count = 0
    ApplicationRecord.transaction do
      subtask = subtasks.create!(
        project: project,
        title: "#{title} - All Test Cases".truncate(255),
        status: 'new',
        created_by_name: created_by_name
      )
      tcs = test_cases.active
      count = tcs.count
      tcs.update_all(task_id: subtask.id)
      update_column(:number_of_test_cases, test_cases.active.count)
      subtask.update_column(:number_of_test_cases, subtask.test_cases.active.count)
    end
    [ subtask, count ]
  rescue ActiveRecord::RecordInvalid
    [ nil, 0 ]
  end

  def subtask?
    !root_task?
  end

  def root_task?
    (parent_id.nil? && redmine_id.nil?) || (parent_id.present? && redmine_id.present?)
  end

  def progress_percentage
    return 0 if estimated_time.nil? || estimated_time.zero? || spent_time.nil?

    [ (spent_time / estimated_time * 100).round(2), 100 ].min
  end

  def overdue?
    due_date.present? && due_date < Date.current && !resolved?
  end

  def resolved?
    COMPLETED_STATUSES.include?(status)
  end

  def unique_devices
    DeviceListBuilder.new(self).build
  end

  def effective_device_config
    return device_config if device_config.present?
    return parent.device_config if parent_id.present? && parent&.device_config.present?

    nil
  end

  def total_test_cases_count
    own_count = test_cases.active.count
    sub_count = TestCase.active.where(task_id: subtasks.select(:id)).count
    own_count + sub_count
  end
end
