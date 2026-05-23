class CellHistorySerializer
  include ActionView::Helpers::DateHelper
  include ActionView::Helpers::SanitizeHelper

  def self.call(logs, field) = new(logs, field).call

  def initialize(logs, field)
    @logs = logs
    @field = field
  end

  def call
    @logs.map do |log|
      old_v, new_v = Array(log.metadata[@field])
      user = log.user
      {
        id: log.id,
        user_name: user&.name || 'System',
        user_initial: (user&.name.to_s.first || '?').upcase,
        action_type: log.action_type,
        time_ago: "#{time_ago_in_words(log.created_at)} ago",
        old_value: sanitize_html(old_v),
        new_value: sanitize_html(new_v),
        can_restore: !old_v.nil?
      }
    end
  end

  private

  ALLOWED_TAGS = %w[b strong i em u a img br p span div].freeze
  ALLOWED_ATTRS = %w[href src alt class style].freeze

  def sanitize_html(v)
    return nil if v.nil?
    sanitize(v.to_s, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRS)
  end
end
