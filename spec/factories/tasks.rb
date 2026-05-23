FactoryBot.define do
  factory :task do
    association :project
    sequence(:title) { |n| "Task #{n}" }
    status { "new" }
    description { "A test task" }

    trait :with_subtask do
      after(:create) do |task|
        create(:task, project: task.project, parent_id: task.id, title: "#{task.title} - Sub")
      end
    end
  end
end
