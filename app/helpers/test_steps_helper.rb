module TestStepsHelper
  URL_PATTERN = %r{(?<!["'=])(https?://[a-zA-Z0-9\-._~:/?#\[\]@!$&'()*+,;=%]+)(?=[.,;:]?(\s|$|<))}

  def format_content_with_media_links(content_value)
    return '' if content_value.blank?

    unescaped = CGI.unescapeHTML(content_value.to_s)
    sanitized = sanitize(unescaped, tags: %w[span b i u br div p strong em a font],
                         attributes: %w[class href target rel style color face size])
    sanitized.gsub(URL_PATTERN) { |match| link_for_content_url(match) }.html_safe
  end

  def link_for_content_url(url)
    processed_url = url.include?('gyazo.com') ? gyazo_to_image_url(url) : url
    is_media = image_url?(processed_url) || video_url?(processed_url)

    if is_media || url.include?('gyazo.com')
      media_type = image_url?(processed_url) ? 'image' : (video_url?(processed_url) ? 'video' : 'link')
      link_to url, '#',
              data: { action: 'click->media-preview#open', url: processed_url, type: media_type },
              class: 'text-decoration-none'
    else
      link_to url, url, target: '_blank', rel: 'noopener noreferrer', class: 'text-primary',
              style: 'word-break: break-all;'
    end
  end
end
