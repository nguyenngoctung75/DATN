class TestCase < ApplicationRecord
  include SoftDeletable
  include Loggable

  belongs_to :task
  belongs_to :created_by, class_name: 'User', foreign_key: 'created_by_id', optional: true

  has_one :test_step, -> { order(:step_number) }, foreign_key: 'case_id', inverse_of: :test_case
  has_many :test_steps, foreign_key: 'case_id', dependent: :destroy, inverse_of: :test_case
  has_many :test_results, foreign_key: 'case_id', dependent: :delete_all

  # Nested attributes for creating single test step
  accepts_nested_attributes_for :test_step, allow_destroy: true

  validates :title, presence: true
  validates :task_id, presence: true

  before_validation :strip_title

  scope :by_type, ->(type) { where(test_type: type) }
  scope :by_target, ->(target) { where(target: target) }
  scope :ordered, -> { order(Arel.sql('COALESCE(position, id) ASC, id ASC')) }

  SORT_DIRECTIONS = { 'asc' => 'ASC', 'desc' => 'DESC' }.freeze

  def self.page_index_for(test_case_id, task:, sort: 'asc', show_archived: false, per: 10)
    tc_sort = SORT_DIRECTIONS[sort] || 'ASC'
    query = task.test_cases.includes(:test_steps, :test_results)
    query = show_archived ? query.deleted : query.active
    all_ids = query.order(Arel.sql("COALESCE(test_cases.position, test_cases.id) #{tc_sort}")).pluck(:"test_cases.id")
    idx = all_ids.index(test_case_id)
    idx ? (idx / per) + 1 : 1
  end

  before_create :assign_default_position

  # Insert TC at a specific position, shift subsequent TCs down
  def self.insert_at_position!(task, target_position)
    task.test_cases.active.where('position >= ?', target_position).update_all('position = position + 1')
  end

  def step_count
    test_steps.count
  end

  def device_results?
    test_results.active.any?
  end

  def latest_status_for(device_or_category)
    results = test_results.active.recent
    # First try exact match
    match = results.find { |r| r.device == device_or_category }
    # Then try category match
    match ||= results.find { |r| device_match?(r.device, device_or_category) }
    match&.status || 'not_run'
  end

  def latest_status_info_for(device_or_category)
    status = latest_status_for(device_or_category)
    bg_class = case status
    when 'pass' then 'bg-success bg-opacity-10'
    when 'fail' then 'bg-danger bg-opacity-10'
    when 'not_run', 'unknown' then ''
    else ''
    end
    { status: status, bg_class: bg_class }
  end

  after_save :update_task_counter
  after_destroy :update_task_counter

  attr_accessor :skip_title_sync
  after_update :sync_grouped_titles, if: -> { saved_change_to_title? && !skip_title_sync }

  attr_accessor :skip_group_description_sync
  after_update :sync_grouped_group_descriptions,
               if: -> { saved_change_to_group_description? && !skip_group_description_sync }

  private

  def sync_grouped_titles
    old_title, new_title = saved_changes[:title]
    return if old_title.blank? || new_title.blank?

    sibling_ids = task.test_cases.active.where(title: old_title).where.not(id: id).pluck(:id)
    return if sibling_ids.empty?

    task.test_cases.where(id: sibling_ids).update_all(title: new_title, updated_at: Time.current)
    SyncGroupedTitlesBroadcastJob.perform_later(task_id, sibling_ids, new_title)
  end

  def sync_grouped_group_descriptions
    old_value, new_value = saved_changes[:group_description]
    return if old_value.blank?

    sibling_ids = task.test_cases.active
                      .where(group_description: old_value)
                      .where.not(id: id)
                      .pluck(:id)
    return if sibling_ids.empty?

    task.test_cases.where(id: sibling_ids)
        .update_all(group_description: new_value, updated_at: Time.current)
    SyncGroupedTitlesBroadcastJob.perform_later(task_id, sibling_ids, new_value, field: 'group_description')
  end

  def strip_title
    if title.present?
      self.title = CGI.unescapeHTML(title.to_s).strip
    end
  end

  def assign_default_position
    return if position.present?
    max_pos = task.test_cases.maximum(:position) || 0
    self.position = max_pos + 1
  end

  def update_task_counter
    recount_task(task_id) if task_id
    if saved_change_to_task_id?
      old_task_id = saved_changes[:task_id].first
      recount_task(old_task_id) if old_task_id
    end
  end

  def recount_task(tid)
    count = TestCase.active.where(task_id: tid).count
    Task.where(id: tid).update_all(number_of_test_cases: count)
  end

  def device_match?(device_name, category)
    DeviceClassifier.match?(device_name, category)
  end
end
