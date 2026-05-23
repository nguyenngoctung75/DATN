FactoryBot.define do
  factory :bug do
    association :task
    sequence(:title) { |n| "Bug #{n}" }
    category { "stg_vn" }
    priority { "normal" }
    status { "new" }
  end
end
