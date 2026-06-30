# frozen_string_literal: true

class AiTestCaseGenerationService
  MAX_TEST_CASES = 30
  DEFAULT_TEST_TYPE = 'Feature'
  DEFAULT_TARGET = 'PC・SP・APP'

  Result = Struct.new(:imported_count, :skipped_count, :errors, keyword_init: true)

  DEFAULT_SYSTEM_PROMPT = <<~PROMPT
    You are an expert QA engineer. Given a feature description (and optional
    context from a GitHub issue or pull request), generate clear, executable
    software test cases. Respond ONLY with JSON matching the provided schema.
    Each test case must include a concise title, a description, a test_type, a
    target, an optional group_description, an optional note, and an ordered list
    of steps; each step has one or more action strings and one or more
    expected-result strings. Cover normal, abnormal/error, and boundary
    scenarios where relevant. Write ALL generated content in English.
  PROMPT

  TC_SCHEMA = {
    'type' => 'ARRAY',
    'items' => {
      'type' => 'OBJECT',
      'properties' => {
        'title' => { 'type' => 'STRING' },
        'description' => { 'type' => 'STRING' },
        'test_type' => { 'type' => 'STRING' },
        'target' => { 'type' => 'STRING' },
        'group_description' => { 'type' => 'STRING' },
        'note' => { 'type' => 'STRING' },
        'steps' => {
          'type' => 'ARRAY',
          'items' => {
            'type' => 'OBJECT',
            'properties' => {
              'description' => { 'type' => 'STRING' },
              'actions' => { 'type' => 'ARRAY', 'items' => { 'type' => 'STRING' } },
              'expectations' => { 'type' => 'ARRAY', 'items' => { 'type' => 'STRING' } }
            }
          }
        }
      },
      'required' => %w[title steps]
    }
  }.freeze

  def initialize(task, description:, user:, github_url: nil, count: nil, client: nil, github_fetcher: nil)
    @task = task
    @description = description.to_s
    @user = user
    @github_url = github_url
    @count = count.to_i
    @client = client || Ai::GeminiClient.new(model: AppConfiguration.instance.ai_model)
    @github_fetcher = github_fetcher || Github::ContentFetcher.new
    @imported_count = 0
    @skipped_count = 0
    @errors = []
  end

  def generate!
    raw = @client.generate(system: system_prompt, user: user_prompt, response_schema: TC_SCHEMA)
    test_cases = raw.is_a?(Array) ? raw : raw['test_cases']
    raise 'Unexpected AI response shape' unless test_cases.is_a?(Array)

    persist(test_cases.first(MAX_TEST_CASES))
    Result.new(imported_count: @imported_count, skipped_count: @skipped_count, errors: @errors)
  end

  private

  def system_prompt
    AppConfiguration.instance.ai_tc_system_prompt.presence || DEFAULT_SYSTEM_PROMPT
  end

  def user_prompt
    parts = [ "Feature description:\n#{@description}" ]
    if @github_url.present? && (context = @github_fetcher.fetch(@github_url)).present?
      parts << "GitHub context:\n#{context}"
    end
    parts << count_instruction
    parts.join("\n\n")
  end

  def count_instruction
    if @count.positive?
      "Generate exactly #{@count.clamp(1, MAX_TEST_CASES)} test cases."
    else
      "Generate an appropriate number of test cases (never more than #{MAX_TEST_CASES})."
    end
  end

  def persist(test_cases)
    ActiveRecord::Base.transaction do
      base_position = @task.test_cases.maximum(:position).to_i
      test_cases.each_with_index do |attrs, index|
        build_test_case(attrs, base_position + index + 1)
      end
      @task.update!(number_of_test_cases: @task.test_cases.active.count)
    end
  end

  def build_test_case(attrs, position)
    return skip! if attrs['title'].blank?

    ActiveRecord::Base.transaction(requires_new: true) do
      test_case = @task.test_cases.create!(
        title: attrs['title'],
        description: attrs['description'],
        test_type: attrs['test_type'].presence || DEFAULT_TEST_TYPE,
        target: attrs['target'].presence || DEFAULT_TARGET,
        group_description: attrs['group_description'],
        note: attrs['note'],
        position: position,
        created_by: @user,
        generated_by_ai: true
      )
      build_steps(test_case, attrs['steps'])
      @imported_count += 1
    end
  rescue ActiveRecord::RecordInvalid => e
    purge_unsaved_test_cases
    @errors << e.message
    skip!
  end

  def purge_unsaved_test_cases
    @task.association(:test_cases).target.reject!(&:new_record?)
  end

  def build_steps(test_case, steps)
    Array(steps).each_with_index do |step, index|
      test_step = test_case.test_steps.create!(step_number: index + 1, description: step['description'])
      create_contents(test_step, step['actions'], 'action')
      create_contents(test_step, step['expectations'], 'expectation')
    end
  end

  def create_contents(test_step, values, category)
    Array(values).each_with_index do |value, order|
      next if value.blank?

      test_step.test_step_contents.create!(
        content_type: 'text',
        content_category: category,
        content_value: value,
        is_expected: category == 'expectation',
        display_order: order
      )
    end
  end

  def skip!
    @skipped_count += 1
  end
end
