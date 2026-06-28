module ProjectsHelper
  DEV_STATUS_META = {
    'planning'       => { label: 'Planning', class: 'bg-secondary' },
    'in_development' => { label: 'In Development', class: 'bg-primary' },
    'testing'        => { label: 'Testing', class: 'bg-warning text-dark' },
    'released'       => { label: 'Released', class: 'bg-success' },
    'maintenance'    => { label: 'Maintenance', class: 'bg-info text-dark' }
  }.freeze

  # Browser-facing Redmine URL. REDMINE_BASE_URL is the in-container API host
  # (e.g. http://redmine:3000) which a browser cannot resolve, so prefer
  # REDMINE_PUBLIC_URL and fall back to mapping the local docker host port.
  def redmine_base_url
    ENV['REDMINE_PUBLIC_URL'].presence ||
      ENV.fetch('REDMINE_BASE_URL', 'https://redmine.example.com').sub('redmine:3000', 'localhost:3001')
  end

  def redmine_project_url(project)
    return nil if project.redmine_project_id.blank?

    "#{redmine_base_url}/projects/#{project.redmine_project_id}"
  end

  def development_status_badge(status)
    meta = DEV_STATUS_META[status.to_s]
    return content_tag(:span, 'Not set', class: 'badge bg-light text-muted border') if meta.nil?

    content_tag(:span, meta[:label], class: "badge #{meta[:class]}")
  end

  # Display name for a user (falls back to email).
  def member_display_name(user)
    user.name.presence || user.email
  end
end
