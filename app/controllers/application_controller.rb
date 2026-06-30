class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :authenticate_user!
  before_action :set_current_user
  before_action :set_header_notifications, unless: -> { request.format.json? }

  private

  def set_header_notifications
    return unless current_user
    visible = Notification.visible_for(current_user)
    @header_notifications = visible.limit(10).to_a
    @header_notifications_unread_count = visible.unread_for(current_user).count
    ids = @header_notifications.map(&:id)
    @header_read_ids = if ids.empty?
      Set.new
    else
      NotificationRead
        .where(user: current_user, notification_id: ids)
        .pluck(:notification_id)
        .to_set
    end
  end

  def set_current_user
    Current.user = current_user
  end

  def require_project_membership!
    return if current_user&.admin?
    return if params[:project_id].blank?

    project = Project.find_by(id: params[:project_id])
    return if project.nil? || project.accessible_to?(current_user)

    raise CanCan::AccessDenied.new('You are not assigned to this project.', :read, Project)
  end

  rescue_from CanCan::AccessDenied do |exception|
    respond_to do |format|
      format.html { redirect_to root_path, alert: exception.message }
      format.json { render json: { error: exception.message }, status: :forbidden }
    end
  end

  def current_ability
    @current_ability ||= Ability.new(current_user)
  end

  def after_sign_in_path_for(resource)
    if resource.admin?
      admin_dashboard_path
    else
      user_dashboard_path
    end
  end
end
