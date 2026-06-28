# frozen_string_literal: true

class ImportRun < ApplicationRecord
  STATUSES = %w[pending running success failed].freeze
  IMPORT_TYPES = %w[manual redmine_bulk redmine_url manual_tc manual_bug clone_tc ai_generate_tc].freeze

  belongs_to :project
  belongs_to :triggered_by, class_name: 'User', optional: true

  VALID_TRANSITIONS = {
    'pending' => %w[running failed],
    'running' => %w[success failed],
    'success' => [],
    'failed'  => []
  }.freeze

  validates :status, inclusion: { in: STATUSES }
  validates :import_type, inclusion: { in: IMPORT_TYPES }
  validate :status_transition_valid, on: :update, if: :status_changed?

  scope :recent, -> { order(started_at: :desc, created_at: :desc) }

  BROADCAST_THROTTLE_SECONDS = 1.0

  def progress_percent
    return 0 if total_count.to_i.zero?

    [ (processed_count.to_f * 100 / total_count).round, 100 ].min
  end

  def finished?
    %w[success failed].include?(status)
  end

  def params
    return {} if params_json.blank?

    JSON.parse(params_json)
  rescue JSON::ParserError
    {}
  end

  def params=(hash)
    self.params_json = hash.is_a?(String) ? hash : hash.to_json
  end

  # Atomic increment without callbacks; throttled broadcast.
  def increment_progress!(by: 1)
    self.class.where(id: id).update_all('processed_count = processed_count + ' + by.to_i.to_s)
    reload
    broadcast_progress if should_broadcast?
  end

  def append_log(line)
    return if line.blank?

    new_log = [ log_output.to_s, line.to_s.strip ].reject(&:blank?).join("\n")
    update_columns(log_output: new_log)
  end

  def broadcast_progress(event: 'import_progress')
    return unless triggered_by

    UserChannel.broadcast_to(triggered_by, broadcast_payload(event))
    @last_broadcast_at = Time.current
  end

  private

  def status_transition_valid
    allowed = VALID_TRANSITIONS[status_was] || []
    return if allowed.include?(status)

    errors.add(:status, "cannot transition from '#{status_was}' to '#{status}'")
  end

  def should_broadcast?
    return true if @last_broadcast_at.nil?

    (Time.current - @last_broadcast_at) >= BROADCAST_THROTTLE_SECONDS
  end

  def broadcast_payload(event)
    {
      event: event,
      import_run_id: id,
      status: status,
      processed_count: processed_count,
      total_count: total_count,
      imported_count: imported_count,
      skipped_count: skipped_count,
      progress_percent: progress_percent,
      error_message: error_message
    }
  end
end
