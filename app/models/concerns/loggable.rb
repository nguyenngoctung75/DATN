module Loggable
  extend ActiveSupport::Concern

  included do
    after_create :log_create
    after_update :log_update
  end

  private

  def log_create
    return if Current.user.nil?

    ActivityLog.create(
      user: Current.user,
      trackable: self,
      action_type: 'create',
      metadata: format_changes(saved_changes.except('created_at', 'updated_at', 'deleted_at'))
    )
  end

  def log_update
    return if Current.user.nil?

    changes = saved_changes.except('updated_at')
    return if changes.empty?

    action = 'update'
    if changes['deleted_at']
      action = changes['deleted_at'][1].present? ? 'delete' : 'restore'
    end

    ActivityLog.create(
      user: Current.user,
      trackable: self,
      action_type: action,
      metadata: format_changes(changes)
    )
  end

  def format_changes(changes)
    changes.each_with_object({}) do |(field, values), formatted|
      reflection = find_reflection(field)
      klass = reflection ? safe_reflection_klass(reflection) : nil

      if klass
        display_name = reflection.name.to_s.humanize
        formatted[display_name] = [ resolve_value(klass, values[0]), resolve_value(klass, values[1]) ]
      else
        formatted[field] = values
      end
    end
  end

  def find_reflection(field)
    self.class.reflections.values.find { |r| r.belongs_to? && r.foreign_key.to_s == field.to_s }
  end

  def safe_reflection_klass(reflection)
    reflection.klass
  rescue StandardError
    nil
  end

  def resolve_value(klass, id)
    return 'N/A' if id.blank?

    record = klass.unscoped.find_by(id: id)
    return id.to_s unless record

    record.try(:name) || record.try(:title) || record.try(:full_name) || id.to_s
  end
end
