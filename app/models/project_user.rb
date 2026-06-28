# frozen_string_literal: true

# Join model: assigns a User as a member of a Project.
# Membership grants the user permission to work on the project's tasks.
class ProjectUser < ApplicationRecord
  belongs_to :project
  belongs_to :user

  validates :user_id, uniqueness: { scope: :project_id }
end
