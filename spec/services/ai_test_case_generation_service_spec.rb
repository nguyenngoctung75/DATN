require "rails_helper"

RSpec.describe AiTestCaseGenerationService do
  let(:project) { create(:project) }
  let(:task) { create(:task, project: project) }
  let(:user) { create(:user) }
  let(:fetcher) { instance_double(Github::ContentFetcher, fetch: nil) }

  let(:valid_ai_response) do
    [
      {
        "title" => "Login with valid credentials",
        "description" => "Happy path",
        "test_type" => "Feature",
        "target" => "PC",
        "steps" => [
          { "description" => "Open login", "actions" => [ "Enter email and password" ],
            "expectations" => [ "User is redirected to dashboard" ] }
        ]
      }
    ]
  end

  def service(client:, count: nil, github_url: nil)
    described_class.new(task, description: "Login feature", user: user,
                              github_url: github_url, count: count,
                              client: client, github_fetcher: fetcher)
  end

  it "creates a test case with steps and contents, marked generated_by_ai" do
    client = instance_double(Ai::GeminiClient, generate: valid_ai_response)
    result = service(client: client).generate!

    expect(result.imported_count).to eq(1)
    tc = task.test_cases.reload.last
    expect(tc.generated_by_ai).to be(true)
    expect(tc.created_by).to eq(user)
    expect(tc.test_steps.count).to eq(1)
    step = tc.test_steps.first
    expect(step.test_step_contents.where(content_category: "action").count).to eq(1)
    expect(step.test_step_contents.where(content_category: "expectation").count).to eq(1)
  end

  it "skips entries without a title and counts them" do
    client = instance_double(Ai::GeminiClient,
                             generate: valid_ai_response + [ { "title" => "", "steps" => [] } ])
    result = service(client: client).generate!
    expect(result.imported_count).to eq(1)
    expect(result.skipped_count).to eq(1)
  end

  it "uses the GitHub context in the prompt when a url is given" do
    allow(fetcher).to receive(:fetch).with("https://github.com/a/b/issues/1").and_return("ISSUE CONTEXT")
    client = instance_double(Ai::GeminiClient)
    expect(client).to receive(:generate) do |system:, user:, response_schema:|
      expect(user).to include("ISSUE CONTEXT")
      valid_ai_response
    end
    service(client: client, github_url: "https://github.com/a/b/issues/1").generate!
  end

  it "raises when the AI response is not an array of test cases" do
    client = instance_double(Ai::GeminiClient, generate: { "unexpected" => true })
    expect { service(client: client).generate! }.to raise_error(/Unexpected AI response/)
  end

  it "caps the number of created test cases at MAX_TEST_CASES" do
    many = Array.new(40) { |i| { "title" => "TC #{i}", "steps" => [] } }
    client = instance_double(Ai::GeminiClient, generate: many)
    result = service(client: client).generate!
    expect(result.imported_count).to eq(AiTestCaseGenerationService::MAX_TEST_CASES)
  end

  it "rolls back a failed entry via savepoint without leaving an orphan test case" do
    bad = { "title" => "Bad TC", "test_type" => "Feature", "target" => "PC",
            "steps" => [ { "description" => "s", "actions" => [ "trigger" ], "expectations" => [ "ok" ] } ] }
    client = instance_double(Ai::GeminiClient, generate: valid_ai_response + [ bad ])

    # Force the content creation to fail only for the bad TC's action value,
    # exercising the per-entry savepoint after the TestCase row is inserted.
    allow_any_instance_of(TestStepContent).to receive(:save!).and_wrap_original do |m, *args, **kwargs|
      raise ActiveRecord::RecordInvalid, m.receiver if m.receiver.content_value == "trigger"

      m.call(*args, **kwargs)
    end

    result = service(client: client).generate!

    expect(result.imported_count).to eq(1)
    expect(result.skipped_count).to eq(1)
    expect(task.test_cases.count).to eq(1)
    expect(task.test_cases.first.title).to eq("Login with valid credentials")
  end
end
