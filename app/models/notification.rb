# frozen_string_literal: true

class Notification < ApplicationRecord
  CATEGORIES = %w[cronjob system info warning].freeze

  has_many :notification_reads, dependent: :destroy

  validates :category, inclusion: { in: CATEGORIES }
  validates :title, presence: true

  scope :recent, -> { order(created_at: :desc) }

  # Notifications visible to this user (cronjob only for admins)
  scope :visible_for, ->(user) {
    base = recent
    return base if user&.admin?

    base.where.not(category: 'cronjob')
  }

  after_create_commit :broadcast_new_notification

  # Notifications not yet read by this user
  scope :unread_for, ->(user) {
    where.not(id: NotificationRead.where(user: user).select(:notification_id))
  }

  def broadcast_payload
    {
      event: 'notification',
      data: {
        id: id,
        title: title,
        message: message.to_s.truncate(80),
        link: link,
        category: category,
        kind: ci_kind?,
        created_at: created_at.iso8601
      }
    }
  end

  private

  # Returns "ci" when this notification was emitted by the CI webhook pipeline,
  # nil otherwise. Used by the frontend to route to the toast UI vs the dropdown.
  def ci_kind?
    title.to_s.start_with?('✅ CI ', '❌ CI ') ? 'ci' : nil
  end

  def broadcast_new_notification
    if category == 'cronjob'
      User.admin.find_each { |u| UserChannel.broadcast_to(u, broadcast_payload) }
    else
      ActionCable.server.broadcast('notifications', broadcast_payload)
    end
  end
end
