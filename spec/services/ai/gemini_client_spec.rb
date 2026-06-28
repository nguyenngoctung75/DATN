require "rails_helper"

RSpec.describe Ai::GeminiClient do
  def client_with(stubs, api_key: "test-key")
    conn = Faraday.new { |b| b.adapter :test, stubs }
    described_class.new(api_key: api_key, model: "gemini-2.0-flash", connection: conn)
  end

  it "parses the JSON array returned in the model text part" do
    payload = { "candidates" => [ { "content" => { "parts" => [ { "text" => '[{"title":"TC1"}]' } ] } } ] }
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post(%r{/models/.*:generateContent}) { [ 200, {}, JSON.generate(payload) ] }
    end
    result = client_with(stubs).generate(system: "s", user: "u")
    expect(result).to eq([ { "title" => "TC1" } ])
  end

  it "raises GeminiError on non-2xx response" do
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post(%r{generateContent}) { [ 429, {}, "rate limited" ] }
    end
    expect { client_with(stubs).generate(system: "s", user: "u") }
      .to raise_error(Ai::GeminiClient::GeminiError)
  end

  it "raises GeminiError when API key is missing" do
    stubs = Faraday::Adapter::Test::Stubs.new
    expect { client_with(stubs, api_key: nil).generate(system: "s", user: "u") }
      .to raise_error(Ai::GeminiClient::GeminiError, /GEMINI_API_KEY/)
  end

  it "raises GeminiError when the model text is not valid JSON" do
    payload = { "candidates" => [ { "content" => { "parts" => [ { "text" => "not json" } ] } } ] }
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post(%r{generateContent}) { [ 200, {}, JSON.generate(payload) ] }
    end
    expect { client_with(stubs).generate(system: "s", user: "u") }
      .to raise_error(Ai::GeminiClient::GeminiError, /Invalid JSON/)
  end

  it "raises GeminiError on a network error" do
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post(%r{generateContent}) { raise Faraday::ConnectionFailed, "connection refused" }
    end
    expect { client_with(stubs).generate(system: "s", user: "u") }
      .to raise_error(Ai::GeminiClient::GeminiError, /HTTP error calling Gemini/)
  end

  it "raises GeminiError when there are no candidates" do
    payload = { "candidates" => [] }
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post(%r{generateContent}) { [ 200, {}, JSON.generate(payload) ] }
    end
    expect { client_with(stubs).generate(system: "s", user: "u") }
      .to raise_error(Ai::GeminiClient::GeminiError, /Empty response/)
  end

  it "includes the response schema in the request body when provided" do
    captured = {}
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post(%r{generateContent}) do |env|
        captured[:body] = env.body
        [ 200, {}, JSON.generate({ "candidates" => [ { "content" => { "parts" => [ { "text" => "[]" } ] } } ] }) ]
      end
    end
    client_with(stubs).generate(system: "s", user: "u", response_schema: { "type" => "ARRAY" })
    expect(captured[:body]).to include("responseSchema")
  end
end
