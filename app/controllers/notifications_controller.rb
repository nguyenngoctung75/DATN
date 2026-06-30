# frozen_string_literal: true

class NotificationsController < ApplicationController
  skip_before_action :set_header_notifications, only: [ :mark_read, :mark_all_read, :read_and_go, :unread_count ]

  def index
    authorize! :read, Notification
    @notifications = Notification.visible_for(current_user).limit(50)
    @read_ids = NotificationRead.where(user: current_user).pluck(:notification_id).to_set
  end

  def read_and_go
    notification = Notification.find(params[:id])
    authorize! :read, notification
    mark_notification_read(notification)
    redirect_to notification.link.presence || root_path
  end

  def mark_read
    notification = Notification.find(params[:id])
    authorize! :read, notification
    mark_notification_read(notification)
    unread_count = Notification.visible_for(current_user).unread_for(current_user).count
    respond_to do |format|
      format.html { redirect_back fallback_location: root_path }
      format.json { render json: { success: true, unread_count: unread_count } }
    end
  end

  def mark_all_read
    authorize! :read, Notification
    Notification.visible_for(current_user).unread_for(current_user).find_each { |n| mark_notification_read(n) }
    respond_to do |format|
      format.html { redirect_back fallback_location: root_path }
      format.json { render json: { success: true, unread_count: 0 } }
    end
  end

  def unread_count
    authorize! :read, Notification
    count = Notification.visible_for(current_user).unread_for(current_user).count
    render json: { unread_count: count }
  end

  private

  def mark_notification_read(notification)
    r = NotificationRead.find_or_initialize_by(user: current_user, notification: notification)
    r.read_at = Time.current
    r.save!
  end
end
