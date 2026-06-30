# frozen_string_literal: true

module Github
  class ContentFetcher
    API_BASE = 'https://api.github.com'
    TIMEOUT_SECONDS = 30
    OPEN_TIMEOUT_SECONDS = 10
    ISSUE_RE = %r{github\.com/([^/]+)/([^/]+)/issues/(\d+)}
    PR_RE = %r{github\.com/([^/]+)/([^/]+)/pull/(\d+)}

    def initialize(token: ENV['GITHUB_TOKEN'], connection: nil)
      @token = token
      @connection = connection || build_connection
    end

    def fetch(url)
      return nil if url.blank?

      if (m = url.match(ISSUE_RE))
        fetch_issue(m[1], m[2], m[3])
      elsif (m = url.match(PR_RE))
        fetch_pr_markdown(m[1], m[2], m[3])
      end
    rescue StandardError => e
      Rails.logger.warn("Github::ContentFetcher failed for #{url}: #{e.message}")
      nil
    end

    private

    def fetch_issue(owner, repo, number)
      response = get("/repos/#{owner}/#{repo}/issues/#{number}")
      return nil unless response.success?

      data = JSON.parse(response.body)
      [ "# #{data['title']}", data['body'] ].compact.join("\n\n").presence
    end

    def fetch_pr_markdown(owner, repo, number)
      response = get("/repos/#{owner}/#{repo}/pulls/#{number}/files")
      return nil unless response.success?

      files = JSON.parse(response.body)
      markdown = files.select { |f| f['filename'].to_s.end_with?('.md') }
      return nil if markdown.empty?

      markdown.map { |f| "## #{f['filename']}\n#{f['patch'] || ''}" }.join("\n\n").presence
    end

    def get(path)
      @connection.get(path) do |req|
        req.headers['Accept'] = 'application/vnd.github+json'
        req.headers['Authorization'] = "Bearer #{@token}" if @token.present?
      end
    end

    def build_connection
      Faraday.new(url: API_BASE) do |f|
        f.options.timeout = TIMEOUT_SECONDS
        f.options.open_timeout = OPEN_TIMEOUT_SECONDS
        f.adapter Faraday.default_adapter
      end
    end
  end
end
