class TestResult < ApplicationRecord
  belongs_to :test_run, foreign_key: 'run_id', optional: true
  belongs_to :test_case, foreign_key: 'case_id'
  belongs_to :executed_by, class_name: 'User', foreign_key: 'executed_by_id', optional: true
  has_one :bug, dependent: :nullify

  STATUSES = %w[pass fail not_run].freeze
  ALL_STATUSES = %w[pass fail not_run unknown].freeze

  validates :case_id, presence: true
  validates :status, presence: true
  validates :status, inclusion: { in: ALL_STATUSES }

  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }
  scope :recent, -> { order(executed_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :failed_with_bugs, -> { where(status: 'fail').joins(:bug) }
  scope :for_task, ->(task_id) { joins(:test_case).where(test_cases: { task_id: task_id }) }
  scope :for_project, ->(project_id) { joins(test_case: :task).where(tasks: { project_id: project_id }) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def active?
    deleted_at.nil?
  end
end
