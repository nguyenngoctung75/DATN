FactoryBot.define do
  factory :test_case do
    association :task
    sequence(:title) { |n| "Test Case #{n}" }
    test_type { "functional" }
    target { "web" }
  end
end
