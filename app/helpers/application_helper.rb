module ApplicationHelper
  def render_toast(message, type: 'info')
    render partial: 'shared/toast', locals: { message: message, type: type }
  end

  CI_STATUS_BADGE = {
    'success' => 'bg-success',
    'failed'  => 'bg-danger',
    'not_run' => 'bg-secondary'
  }.freeze

  CI_STATUS_LABEL = {
    'success' => 'PASS',
    'failed'  => 'FAIL',
    'not_run' => 'NOT RUN'
  }.freeze

  def ci_status_badge_class(status)
    CI_STATUS_BADGE[status.to_s] || 'bg-secondary'
  end

  def ci_status_label(status)
    CI_STATUS_LABEL[status.to_s] || status.to_s.upcase
  end

  def status_badge_color(status)
    case status.to_s.downcase
    when 'new', 'open'
      'bg-primary text-white'
    when 'pending'
      'bg-warning text-dark'
    when 'in progress', 'in_progress', 'working'
      'bg-info text-dark'
    when 'resolved', 'fixed'
      'bg-success text-white'
    when 'waiting release', 'waiting_release'
      'bg-secondary text-white'
    when 'closed', 'done'
      'bg-dark text-white'
    when 'feedback', 'reopen', 'reopened'
      'bg-danger text-white'
    when 'testing', 'verify'
      'bg-warning text-dark'
    else
      'bg-secondary text-white'
    end
  end

  def gyazo_to_image_url(url)
    return url if url.blank?

    if url.match?(%r{^https?://gyazo\.com/([a-zA-Z0-9]+)})
      image_id = url.match(%r{gyazo\.com/([a-zA-Z0-9]+)})[1]
      "https://gyazo.com/#{image_id}/raw"
    else
      url
    end
  end

  def image_url?(url)
    (url.present? && url.match?(/\.(png|jpg|jpeg|gif|webp)$/i)) || url.to_s.include?('gyazo.com')
  end

  def video_url?(url)
    url.present? && url.match?(/\.(mp4|webm|mov)$/i)
  end

  def render_media(url, max_height: '400px')
    return if url.blank?

    return unless url.match?(%r{https?://[^\s<]+})

    processed_url = url.match(%r{https?://[^\s<]+})[0]
    processed_url = gyazo_to_image_url(processed_url) if processed_url.include?('gyazo.com')

    if image_url?(processed_url)
      link_to processed_url, target: '_blank', rel: 'noopener noreferrer', class: 'd-block mt-2' do
        image_tag processed_url, class: 'img-fluid rounded border shadow-sm', style: "max-height: #{max_height};"
      end
    elsif video_url?(processed_url)
      content_tag :div, class: 'mt-2' do
        video_tag processed_url, controls: true, class: 'img-fluid rounded border shadow-sm',
                                 style: "max-height: #{max_height};"
      end
    else
      link_to processed_url, processed_url, target: '_blank', rel: 'noopener noreferrer',
              class: 'small text-primary d-block mt-1 text-truncate', style: 'max-width: 100%;'
    end
  end
end
