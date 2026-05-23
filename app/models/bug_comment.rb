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

  def author_name
    user&.name || 'Unknown User'
  end

  def short_content(length = 50)
    return content if content.length <= length

    "#{content[0...length]}..."
  end

  def created_time_ago
    time_diff = Time.current - created_at

    case time_diff
    when 0..59
      "#{time_diff.to_i} seconds ago"
    when 60..3599
      "#{(time_diff / 60).to_i} minutes ago"
    when 3600..86_399
      "#{(time_diff / 3600).to_i} hours ago"
    when 86_400..2_591_999
      "#{(time_diff / 86_400).to_i} days ago"
    else
      created_at.strftime('%d/%m/%Y %H:%M')
    end
  end
end
