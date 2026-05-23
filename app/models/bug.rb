class Bug < ApplicationRecord
  include SoftDeletable
  include Loggable

  belongs_to :task
  belongs_to :dev, class_name: 'User', foreign_key: 'dev_id', optional: true
  belongs_to :tester, class_name: 'User', foreign_key: 'tester_id', optional: true
  belongs_to :test_result, optional: true

  has_many :bug_evidences, dependent: :destroy
  has_many :bug_comments, dependent: :nullify

  CATEGORIES = %w[stg_vn stg_jp new_requirement prod].freeze
  PRIORITIES = %w[high normal low].freeze
  STATUSES = %w[new fixing testing pending done].freeze
  OPEN_STATUSES = %w[new fixing testing pending].freeze

  validates :title, presence: true
  validates :task_id, presence: true
  validates :category, inclusion: { in: CATEGORIES }
  validates :priority, inclusion: { in: PRIORITIES }
  validates :status, inclusion: { in: STATUSES }

  scope :open, -> { where(status: OPEN_STATUSES) }
  scope :closed, -> { where(status: 'done') }
  scope :by_category, ->(category) { where(category: category) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :by_application, ->(app) { where(application: app) }

  def open?
    OPEN_STATUSES.include?(status)
  end

  def closed?
    status == 'done'
  end

  def evidence_count
    bug_evidences.count
  end

  def from_test_result?
    test_result_id.present?
  end
end
