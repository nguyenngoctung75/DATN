class BugComment < ApplicationRecord
  belongs_to :bug
  belongs_to :user

  validates :bug_id, presence: true
  validates :user_id, presence: true
  validates :content, presence: true

  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :oldest_first, -> { order(created_at: :asc) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def active?
    deleted_at.nil?
  end
end
