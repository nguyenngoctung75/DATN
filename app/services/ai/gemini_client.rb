# frozen_string_literal: true

module Ai
  class GeminiClient
    class GeminiError < StandardError; end

    BASE_URL = 'https://generativelanguage.googleapis.com/v1beta'
    DEFAULT_MODEL = 'gemini-2.0-flash'
    TIMEOUT_SECONDS = 60
    OPEN_TIMEOUT_SECONDS = 10

    def initialize(api_key: ENV['GEMINI_API_KEY'], model: DEFAULT_MODEL, connection: nil)
      @api_key = api_key
      @model = model.presence || DEFAULT_MODEL
      @connection = connection || build_connection
    end

    # Returns the parsed JSON value produced by the model (Array or Hash).
    def generate(system:, user:, response_schema: nil)
      raise GeminiError, 'Missing GEMINI_API_KEY' if @api_key.blank?

      response = @connection.post(generate_path) do |req|
        req.headers['Content-Type'] = 'application/json'
        req.body = JSON.generate(build_body(system, user, response_schema))
      end
      handle_response(response)
    rescue Faraday::Error => e
      raise GeminiError, "HTTP error calling Gemini: #{e.message}"
    end

    private

    def generate_path
      "models/#{@model}:generateContent?key=#{@api_key}"
    end

    def build_body(system, user, schema)
      generation_config = { 'responseMimeType' => 'application/json' }
      generation_config['responseSchema'] = schema if schema
      {
        'system_instruction' => { 'parts' => [ { 'text' => system } ] },
        'contents' => [ { 'role' => 'user', 'parts' => [ { 'text' => user } ] } ],
        'generationConfig' => generation_config
      }
    end

    def handle_response(response)
      raise GeminiError, "Gemini API returned #{response.status}" unless response.success?

      outer = JSON.parse(response.body)
      text = outer.dig('candidates', 0, 'content', 'parts', 0, 'text')
      raise GeminiError, 'Empty response from Gemini' if text.blank?

      JSON.parse(text)
    rescue JSON::ParserError => e
      raise GeminiError, "Invalid JSON from Gemini: #{e.message}"
    end

    # NOTE: the API key is in the query string per Gemini's API spec. Do NOT add
    # `f.response :logger` to this connection — it would write the key to logs.
    def build_connection
      Faraday.new(url: BASE_URL) do |f|
        f.options.timeout = TIMEOUT_SECONDS
        f.options.open_timeout = OPEN_TIMEOUT_SECONDS
        f.adapter Faraday.default_adapter
      end
    end
  end
end
