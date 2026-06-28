require 'rails_helper'

RSpec.describe Github::ContentFetcher do
  def fetcher_with(stubs)
    conn = Faraday.new { |b| b.adapter :test, stubs }
    described_class.new(token: nil, connection: conn)
  end

  it 'returns nil for blank url' do
    expect(fetcher_with(Faraday::Adapter::Test::Stubs.new).fetch(nil)).to be_nil
  end

  it 'fetches issue title and body' do
    body = { 'title' => 'Login bug', 'body' => 'Steps to reproduce' }
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get('/repos/acme/app/issues/12') { [ 200, {}, JSON.generate(body) ] }
    end
    result = fetcher_with(stubs).fetch('https://github.com/acme/app/issues/12')
    expect(result).to include('Login bug').and include('Steps to reproduce')
  end

  it 'fetches only .md file patches from a PR' do
    files = [
      { 'filename' => 'docs/spec.md', 'patch' => '+ new spec line' },
      { 'filename' => 'app/foo.rb', 'patch' => '+ code' }
    ]
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get('/repos/acme/app/pulls/7/files') { [ 200, {}, JSON.generate(files) ] }
    end
    result = fetcher_with(stubs).fetch('https://github.com/acme/app/pull/7')
    expect(result).to include('docs/spec.md').and include('new spec line')
    expect(result).not_to include('app/foo.rb')
  end

  it 'returns nil and does not raise on HTTP error' do
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get(%r{/repos/.*}) { [ 404, {}, 'not found' ] }
    end
    expect(fetcher_with(stubs).fetch('https://github.com/acme/app/issues/99')).to be_nil
  end
end
