require 'faraday'
require 'json'

class RedmineService
  BASE_URL = ENV.fetch('REDMINE_BASE_URL', 'https://redmine.example.com').freeze
  API_KEY = ENV['REDMINE_API_KEY'].freeze
  USERNAME = ENV['REDMINE_USERNAME'].freeze
  PASSWORD = ENV['REDMINE_PASSWORD'].freeze

  # GET /projects.json - list projects (id, name, identifier)
  def self.get_projects_list
    conn = connection
    response = conn.get('/projects.json?limit=1000')
    return [] unless response.success?

    parsed = JSON.parse(response.body)
    projects = parsed['projects'] || []
    projects.map { |p| { id: p['id'], name: p['name'].to_s, identifier: p['identifier'].to_s } }
  rescue JSON::ParserError, Faraday::Error => e
    Rails.logger.error "RedmineService: get_projects_list #{e.message}"
    []
  end

  # GET /projects/:id_or_identifier.json - single project (id or identifier like "usedcar-ex")
  def self.get_project(id_or_identifier)
    return nil if id_or_identifier.blank?

    conn = connection
    id_escaped = CGI.escape(id_or_identifier.to_s)
    response = conn.get("/projects/#{id_escaped}.json")
    return nil unless response.success?

    parsed = JSON.parse(response.body)
    parsed['project']
  rescue JSON::ParserError, Faraday::Error => e
    Rails.logger.error "RedmineService: get_project #{e.message}"
    nil
  end

  # Resolve project id: if input is numeric return as-is, else fetch by identifier and return id.
  def self.resolve_project_id(id_or_identifier)
    return nil if id_or_identifier.blank?

    str = id_or_identifier.to_s.strip
    return str if str.match?(/\A\d+\z/)

    project = get_project(str)
    project ? project['id'].to_s : nil
  end

  def self.get_issues(issue_id)
    conn = connection
    response = conn.get("/issues/#{issue_id}.json")

    if response.success?
      begin
        raw_body = response.body
        parsed_json = JSON.parse(raw_body)
        parsed_json['issue']
      rescue JSON::ParserError => e
        Rails.logger.error "RedmineService: error parse JSON: #{e.message}"
        nil
      end
    else
      parsed = (JSON.parse(response.body) rescue {})
      errors = Array(parsed['errors']).join(', ')
      Rails.logger.error "RedmineService: API error #{response.status} #{errors}"
      nil
    end
  rescue Faraday::Error => e
    Rails.logger.error "RedmineService: Error getting issues: #{e.message}"
    nil
  end

  # Build issues URL with optional filters: project_id, date range (created_on)
  # Returns path + query (e.g. "/issues.json?limit=100&..."). Use with BASE_URL for full URL.
  def self.build_issues_url(base_url, limit: 100, offset: 0, project_id: nil, created_on_from: nil, created_on_to: nil)
    uri = URI(base_url)
    base_path = uri.path.presence || '/'
    path = if base_path.end_with?('.json')
             base_path
    elsif base_path == '/' || base_path.empty?
             '/issues.json'
    else
             "#{base_path}.json"
    end

    query_params = []
    query_params << uri.query if uri.query.present?
    query_params << "limit=#{limit}&offset=#{offset}"
    query_params << "project_id=#{project_id}" if project_id.present?

    if created_on_from.present? && created_on_to.present?
      query_params << "created_on=#{CGI.escape("><#{created_on_from}|#{created_on_to}")}"
    elsif created_on_from.present?
      query_params << "created_on=#{CGI.escape(">=#{created_on_from}")}"
    elsif created_on_to.present?
      query_params << "created_on=#{CGI.escape("<=#{created_on_to}")}"
    end

    path + (path.include?('?') ? '&' : '?') + query_params.join('&')
  end

  # Fetch issues list from URL (e.g. https://redmine.example.com/issues.json)
  # Optional: project_id (Redmine project ID), created_on_from, created_on_to (Date or string YYYY-MM-DD).
  # Returns { issues: [...], total_count:, offset:, limit: }
  def self.get_issues_list(url, limit: 100, offset: 0, project_id: nil, created_on_from: nil, created_on_to: nil)
    base_url = base_url_from_uri(URI(url))
    from_str = format_date_param(created_on_from)
    to_str = format_date_param(created_on_to)
    path = build_issues_url(url, limit: limit, offset: offset, project_id: project_id,
                            created_on_from: from_str, created_on_to: to_str)

    response = connection_for_url(base_url).get(path)
    parse_issues_response(response, offset, limit)
  rescue Faraday::Error, URI::InvalidURIError => e
    Rails.logger.error "RedmineService: Error fetching issues list: #{e.message}"
    nil
  end

  def self.base_url_from_uri(uri)
    port_suffix = (uri.port && uri.port != 80 && uri.port != 443) ? ":#{uri.port}" : ''
    "#{uri.scheme}://#{uri.host}#{port_suffix}"
  end

  def self.parse_issues_response(response, offset, limit)
    return nil unless response.success?

    parsed = JSON.parse(response.body)
    {
      issues: parsed['issues'] || [],
      total_count: parsed['total_count'] || 0,
      offset: parsed['offset'] || offset,
      limit: parsed['limit'] || limit
    }
  rescue JSON::ParserError => e
    Rails.logger.error "RedmineService: error parse JSON: #{e.message}"
    nil
  end

  def self.connection_for_url(base_url = BASE_URL)
    Faraday.new(url: base_url) do |faraday|
      faraday.headers['Content-Type'] = 'application/json'
      faraday.headers['X-Redmine-API-Key'] = API_KEY
      faraday.basic_auth(USERNAME, PASSWORD)
      faraday.options.timeout = 10
      faraday.options.open_timeout = 5
      faraday.response :logger
      faraday.adapter Faraday.default_adapter
    end
  end

  def self.connection
    @connection ||= connection_for_url(BASE_URL)
  end

  def self.format_date_param(val)
    val.respond_to?(:strftime) ? val.strftime('%Y-%m-%d') : val.to_s.presence
  end
  private_class_method :format_date_param
end
