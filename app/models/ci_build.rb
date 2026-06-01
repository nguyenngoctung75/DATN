# frozen_string_literal: true

class CiBuild < ApplicationRecord
  STATUSES = %w[success failed not_run].freeze

  belongs_to :task, optional: true

  validates :commit_sha, :branch, :status, :workflow_run_id, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :workflow_run_id, uniqueness: true

  scope :recent, -> { order(created_at: :desc) }

  def succeeded?
    status == 'success'
  end

  def failed?
    status == 'failed'
  end

  def not_run?
    status == 'not_run'
  end

  def short_sha
    commit_sha.to_s.first(7)
  end
end
