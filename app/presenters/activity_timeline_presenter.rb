class ActivityTimelinePresenter
  IGNORED_FIELDS = %w[
    created_at updated_at deleted_at
    number_of_test_cases subtasks_count subtask_id position redmine_id
    created_by_name reviewed_by_name stg_bugs_vn stg_bugs_jp prod_bugs
    generated_by_ai display_order step_number
  ].freeze
  GROUP_WINDOW = 5.minutes

  TimelineEntry = Data.define(
    :user, :action_type, :action_label, :created_at,
    :changes, :grouped_count, :dot_class, :icon_class, :trackable_type
  )

  FieldChange = Data.define(:label, :old_display, :new_display, :long_text)

  def initialize(logs)
    @logs = logs
  end

  def entries
    @entries ||= build_entries
  end

  def total_count
    @total_count ||= filtered_logs.size
  end

  private

  def filtered_logs
    @filtered_logs ||= @logs.select { |log| significant?(log) }
  end

  def significant?(log)
    return true if log.action_type.in?(%w[create delete restore soft_delete])
    return false if log.metadata.blank?

    log.metadata.any? do |field, values|
      next false if IGNORED_FIELDS.include?(field)
      next false if trivial_diff?(values)

      true
    end
  end

  def trivial_diff?(values)
    return false unless values.is_a?(Array) && values.size == 2

    v0, v1 = values
    return true if v0.to_s == v1.to_s

    (v0.to_s.strip.empty? || v0.to_s.downcase == 'n/a') &&
      (v1.to_s.strip.empty? || v1.to_s.downcase == 'n/a')
  end

  def build_entries
    user_lookup = build_user_lookup(filtered_logs)
    group_logs(filtered_logs).map { |group| build_entry(group, user_lookup) }
  end

  def group_logs(logs)
    groups = []
    logs.each do |log|
      if can_merge?(groups.last, log)
        groups.last << log
      else
        groups << [ log ]
      end
    end
    groups
  end

  def can_merge?(group, log)
    return false if group.nil? || group.empty?

    prev = group.first
    prev.action_type == 'update' &&
      log.action_type == 'update' &&
      prev.user_id == log.user_id &&
      (prev.created_at - log.created_at).abs <= GROUP_WINDOW
  end

  def build_user_lookup(logs)
    ids = logs.flat_map do |log|
      next [] if log.metadata.blank?

      log.metadata.flat_map do |field, values|
        next [] unless field.end_with?('_id') || %w[Assignee Tester Developer].include?(field)

        Array(values).filter_map { |v| v.to_i if v.to_s.match?(/^\d+$/) }
      end
    end

    ids.any? ? User.where(id: ids).index_by(&:id) : {}
  end

  def build_entry(group, user_lookup)
    primary = group.first
    merged_changes = group.flat_map { |log| extract_changes(log, user_lookup) }.uniq(&:label)

    TimelineEntry.new(
      user: primary.user,
      action_type: primary.action_type,
      action_label: action_label_for(primary.action_type),
      created_at: primary.created_at,
      changes: merged_changes,
      grouped_count: group.size,
      dot_class: dot_class_for(primary.action_type),
      icon_class: icon_class_for(primary.action_type),
      trackable_type: primary.trackable_type
    )
  end

  def extract_changes(log, user_lookup)
    return [] if log.metadata.blank? || log.action_type != 'update'

    log.metadata.filter_map do |field, values|
      next if IGNORED_FIELDS.include?(field)
      next unless values.is_a?(Array) && values.size == 2
      next if trivial_diff?(values)

      old_v, new_v = values.map(&:to_s)

      if field.end_with?('_id') || %w[Assignee Tester Developer].include?(field)
        old_v = user_lookup[old_v.to_i]&.name || old_v if old_v.match?(/^\d+$/)
        new_v = user_lookup[new_v.to_i]&.name || new_v if new_v.match?(/^\d+$/)
      end

      old_display = old_v.presence || '(empty)'
      new_display = new_v.presence || '(empty)'

      FieldChange.new(
        label: field.humanize,
        old_display: old_display,
        new_display: new_display,
        long_text: [ old_display, new_display ].any? { |v| v.length > 120 }
      )
    end
  end

  def action_label_for(action_type)
    { 'create' => 'created', 'update' => 'updated', 'delete' => 'deleted',
      'restore' => 'restored', 'soft_delete' => 'deleted', 'import' => 'synced' }.fetch(action_type, action_type)
  end

  def dot_class_for(action_type)
    { 'create' => 'dot-create', 'update' => 'dot-update', 'delete' => 'dot-delete',
      'restore' => 'dot-restore', 'soft_delete' => 'dot-delete' }.fetch(action_type, 'dot-update')
  end

  def icon_class_for(action_type)
    { 'create' => 'bi-plus-circle', 'update' => 'bi-pencil-square', 'delete' => 'bi-trash',
      'restore' => 'bi-arrow-counterclockwise', 'soft_delete' => 'bi-trash' }.fetch(action_type, 'bi-pencil-square')
  end
end
