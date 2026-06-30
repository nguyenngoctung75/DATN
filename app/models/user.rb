class User < ApplicationRecord
  include SoftDeletable

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :assigned_tasks, class_name: 'Task', foreign_key: 'assignee_id', dependent: :nullify
  has_many :created_test_cases, class_name: 'TestCase', foreign_key: 'created_by_id', dependent: :nullify
  has_many :test_runs, foreign_key: 'executed_by_id', dependent: :nullify
  has_many :test_results, foreign_key: 'executed_by_id', dependent: :nullify
  has_many :dev_bugs, class_name: 'Bug', foreign_key: 'dev_id', dependent: :nullify
  has_many :tester_bugs, class_name: 'Bug', foreign_key: 'tester_id', dependent: :nullify

  has_many :project_users, dependent: :destroy
  has_many :projects, through: :project_users

  def accessible_project_ids
    Project.where(open_to_all_users: true).ids | project_ids
  end

  enum :role, { admin: 0, user: 1 }, default: :user

  validates :email, presence: true, uniqueness: true, format: {
    with: /@example\.com\z/,
    message: 'must have @example.com'
  }
  validates :provider, presence: true
  validates :role, presence: true
end
