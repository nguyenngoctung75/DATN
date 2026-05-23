# frozen_string_literal: true

class DailyImportRun < ApplicationRecord
  belongs_to :project

  STATUSES = %w[pending running success failed skipped].freeze

  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(started_at: :desc) }

  def log_lines
    return [] if log_output.blank?
    log_output.split("\n").map(&:strip).reject(&:blank?)
  end
end
