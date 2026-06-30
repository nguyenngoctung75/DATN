class ActivityLog < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :trackable, polymorphic: true

  default_scope { order(created_at: :desc) }

  scope :by_action, ->(action) { where(action_type: action) }
  scope :by_trackable_type, ->(type) { where(trackable_type: type) }
  scope :for_projects, -> { where(trackable_type: 'Project') }

  def action_display
    case action_type
    when 'create' then 'created'
    when 'update' then 'updated'
    when 'delete' then 'deleted'
    when 'restore' then 'restored'
    when 'import' then 'synced'
    else action_type
    end
  end

  def action_description
    case action_type
    when 'create' then 'Created project'
    when 'update' then 'Updated project'
    when 'delete' then 'Archived project'
    when 'restore' then 'Restored project'
    when 'destroy' then 'Permanently deleted project'
    else action_type.humanize
    end
  end

  def changes_summary
    return 'No changes recorded' if metadata.blank?

    changes = []
    metadata.each do |key, values|
      next if key == 'updated_at'

      old_val, new_val = values.is_a?(Array) ? values : [ nil, values ]

      if old_val.nil? && new_val.present?
        changes << "Set #{key} to '#{new_val}'"
      elsif new_val.nil? && old_val.present?
        changes << "Removed #{key} (was '#{old_val}')"
      elsif old_val != new_val
        changes << "Changed #{key} from '#{old_val}' to '#{new_val}'"
      end
    end

    changes.any? ? changes.join(', ') : 'No significant changes'
  end

  def field_changes
    return {} if metadata.blank?

    changes = {}
    metadata.each do |key, values|
      next if key == 'updated_at'

      old_val, new_val = values.is_a?(Array) ? values : [ nil, values ]
      changes[key] = { old: old_val, new: new_val } if old_val != new_val
    end

    changes
  end
end
