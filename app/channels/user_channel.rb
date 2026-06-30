# frozen_string_literal: true

class UserChannel < ApplicationCable::Channel
  def subscribed
    stream_from 'notifications'
    stream_for current_user
  end

  def unsubscribed
    stop_all_streams
  end
end
