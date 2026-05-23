FactoryBot.define do
  factory :notification do
    sequence(:title) { |n| "Notification #{n}" }
    message { "Test message" }
    category { "info" }
    link { nil }
  end
end
