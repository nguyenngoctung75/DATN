# frozen_string_literal: true

# Shared channel for realtime events (notifications, etc.).
# - stream "notifications": global, all subscribed users receive (for system, info, warning).
# - stream_for current_user: per-user stream; cronjob notifications are broadcast only to admins here.
class UserChannel < ApplicationCable::Channel
  def subscribed
    stream_from 'notifications'
    stream_for current_user
  end

  def unsubscribed
    stop_all_streams
  end
end
