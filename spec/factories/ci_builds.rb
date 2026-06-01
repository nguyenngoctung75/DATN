FactoryBot.define do
  factory :ci_build do
    sequence(:workflow_run_id) { |n| "1700000#{n}" }
    sequence(:commit_sha)      { |n| "abcdef1234567890#{n.to_s.rjust(4, '0')}" }
    branch                     { 'feat/sample' }
    base_branch                { 'main' }
    status                     { 'success' }
    author                     { 'tester' }
    repository                 { 'org/tooltest' }
    redmine_link               { 'https://redmine.local/issues/1' }
    redmine_issue_id           { 1 }
    occurred_at                { Time.current }
    raw_payload                { {} }
  end
end
