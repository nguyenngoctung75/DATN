FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    name { "Test User" }
    provider { "local" }
    role { :user }

    trait :admin do
      sequence(:email) { |n| "admin#{n}@example.com" }
      name { "Admin User" }
      role { :admin }
    end
  end
end
