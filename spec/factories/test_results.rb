FactoryBot.define do
  factory :test_result do
    association :test_case
    status { "pass" }
    device { "iPhone 15" }
  end
end
