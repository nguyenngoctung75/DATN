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

  TEST_PHASES = %w[not_started creating_testcases executing reporting completed].freeze
  TEST_PHASE_LABELS = {
    'not_started' => 'Not Started',
    'creating_testcases' => 'Creating Test Cases',
    'executing' => 'Executing Test Cases',
    'reporting' => 'Reporting',
    'completed' => 'Completed'
  }.freeze

  CLONABLE_DEST_PHASES = %w[not_started creating_testcases].freeze

  TESTING_TYPES = %w[new_feature regression retest smoke integration performance other].freeze
  TESTING_TYPE_LABELS = {
    'new_feature' => 'New Feature Testing',
    'regression' => 'Regression Testing',
    'retest' => 'Retest (after fix)',
    'smoke' => 'Smoke Testing',
    'integration' => 'Integration Testing',
    'performance' => 'Performance Testing',
    'other' => 'Other'
  }.freeze

  KPIS = {
    'test_execution_rate' => {
      label: 'Test Execution Rate', unit: '%', higher_is_better: true, default_target: 100,
      hint: 'Percentage of test cases executed out of the total test cases. Formula: executed TC / total TC × 100.'
    },
    'defect_detection_efficiency' => {
      label: 'Defect Detection Efficiency', unit: '%', higher_is_better: true, default_target: 90,
      hint: 'Share of bugs found during testing vs all bugs. Formula: bugs found in testing / total bugs × 100.'
    },
    'test_case_effectiveness' => {
      label: 'Test Case Effectiveness', unit: '%', higher_is_better: true, default_target: 30,
      hint: 'Percentage of test cases that found at least one bug. Higher means more valuable test cases.'
    },
    'on_time_completion' => {
      label: 'On-time Completion', unit: '%', higher_is_better: true, default_target: 100,
      hint: 'Whether testing finished on time: 100 if completed on or before the due date, otherwise 0.'
    },
    'defect_leakage' => {
      label: 'Defect Leakage', unit: '%', higher_is_better: false, default_target: 5,
      hint: 'Bugs that escaped to production: production bugs / total bugs × 100 (lower is better).'
    },
    'tc_design_productivity' => {
      label: 'TC Design Productivity', unit: 'TC/h', higher_is_better: true, default_target: 5,
      hint: 'Number of test cases designed per spent hour. Formula: total test cases / spent time (hours).'
    }
  }.freeze

  belongs_to :project
  belongs_to :assignee, class_name: 'User', foreign_key: 'assignee_id', optional: true
  belongs_to :parent, class_name: 'Task', foreign_key: 'parent_id', counter_cache: :subtasks_count, optional: true

  has_many :subtasks, class_name: 'Task', foreign_key: 'parent_id', dependent: :destroy
  has_many :test_cases, dependent: :destroy
  has_many :test_runs, dependent: :destroy
  has_many :bugs, dependent: :destroy
  has_many :ci_builds, dependent: :nullify

  validates :title, presence: true
  validates :status, inclusion: { in: STATUSES, allow_nil: true }
  validates :test_phase, inclusion: { in: TEST_PHASES, allow_nil: true }
  validates :testing_type, inclusion: { in: TESTING_TYPES, allow_blank: true }
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
  scope :clonable_destinations, -> { where(test_phase: CLONABLE_DEST_PHASES) }

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
      tcs = test_cases.active.where(title: function_name)
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

  def executed_test_cases_count
    TestResult.where(case_id: test_cases.active.select(:id)).distinct.count(:case_id)
  end

  def test_phase_label
    TEST_PHASE_LABELS[test_phase] || 'Not Started'
  end

  def testing_type_label
    TESTING_TYPE_LABELS[testing_type]
  end

  def kpi_target(key)
    stored = kpi_targets.is_a?(Hash) ? kpi_targets[key.to_s] : nil
    value = stored.presence || KPIS.dig(key.to_s, :default_target)
    value&.to_f
  end

  def kpi_actuals
    total_tc = total_test_cases_count
    executed = executed_test_cases_count
    stg = (stg_bugs_vn || 0) + (stg_bugs_jp || 0)
    prod = prod_bugs || 0
    total_bugs = stg + prod

    {
      'test_execution_rate' => percentage(executed, total_tc),
      'defect_detection_efficiency' => percentage(stg, total_bugs),
      'test_case_effectiveness' => percentage([ stg, total_tc ].min, total_tc),
      'on_time_completion' => on_time_completion_value,
      'defect_leakage' => percentage(prod, total_bugs),
      'tc_design_productivity' => productivity_value(total_tc)
    }
  end

  private

  def percentage(part, total)
    return nil if total.nil? || total.zero?

    (part.to_f / total * 100).round(1)
  end

  def productivity_value(total_tc)
    return nil if spent_time.nil? || spent_time.to_f.zero?

    (total_tc / spent_time.to_f).round(2)
  end

  def on_time_completion_value
    return nil if due_date.blank?
    return nil unless test_phase == 'completed'

    updated_at.to_date <= due_date ? 100.0 : 0.0
  end
end
