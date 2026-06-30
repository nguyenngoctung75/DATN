class TestRun < ApplicationRecord
  belongs_to :task
  belongs_to :executed_by, class_name: 'User', foreign_key: 'executed_by_id', optional: true

  has_many :test_results, foreign_key: 'run_id', dependent: :delete_all

  STATUSES = %w[pending running completed aborted].freeze
  IN_PROGRESS_STATUSES = %w[pending running].freeze
  FINISHED_STATUSES = %w[completed aborted].freeze

  validates :name, presence: true
  validates :task_id, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }
  scope :recent, -> { order(executed_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :in_progress, -> { where(status: IN_PROGRESS_STATUSES) }
  scope :finished, -> { where(status: FINISHED_STATUSES) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def active?
    deleted_at.nil?
  end

  def in_progress?
    IN_PROGRESS_STATUSES.include?(status)
  end

  def finished?
    FINISHED_STATUSES.include?(status)
  end

  def pass_count
    results_by_status['pass'] || 0
  end

  def fail_count
    results_by_status['fail'] || 0
  end

  def not_run_count
    results_by_status['not_run'] || 0
  end

  def result_count
    test_results.active.count
  end

  def pass_rate
    total = pass_count + fail_count + not_run_count
    return 0 if total.zero?

    (pass_count.to_f / total * 100).round(2)
  end

  def execution_duration
    return nil if started_at.nil? || completed_at.nil?

    completed_at - started_at
  end

  def execution_duration_formatted
    return 'N/A' if execution_duration.nil?

    seconds = execution_duration.to_i
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    secs = seconds % 60

    if hours.positive?
      "#{hours}h #{minutes}m #{secs}s"
    elsif minutes.positive?
      "#{minutes}m #{secs}s"
    else
      "#{secs}s"
    end
  end

  def results_by_status
    @results_by_status ||= if test_results.loaded?
      test_results.select(&:active?).group_by(&:status).transform_values(&:count)
    else
      test_results.active.group(:status).count
    end
  end

  def start!
    raise InvalidTransition, "Cannot start a #{status} test run" unless status == 'pending'

    update!(status: 'running', started_at: Time.current)
  end

  def complete!
    raise InvalidTransition, "Cannot complete a #{status} test run" unless status == 'running'

    update!(status: 'completed', completed_at: Time.current)
  end

  def abort!
    raise InvalidTransition, "Cannot abort a #{status} test run" unless status == 'running'

    update!(status: 'aborted', completed_at: Time.current)
  end

  class InvalidTransition < StandardError; end

  def status_color
    case status
    when 'running' then 'info'
    when 'completed' then 'success'
    when 'aborted' then 'danger'
    else 'secondary'
    end
  end
end
