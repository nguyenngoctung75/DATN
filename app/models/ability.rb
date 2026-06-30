# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new

    if user.admin?
      can :manage, :all
    elsif user.user?
      define_user_abilities(user)
    else
      cannot :manage, :all
    end
  end

  private

  def define_user_abilities(user)
    ids = user.accessible_project_ids

    can :read, Project, id: ids
    can :read, ImportRun, project_id: ids

    can %i[read create update destroy soft_delete restore report], Task, project_id: ids
    can %i[read create update clone clone_bulk soft_delete restore ai_generate history], TestCase,
        task: { project_id: ids }
    can %i[read create update soft_delete restore history], Bug, task: { project_id: ids }
    can %i[create update], BugComment, bug: { task: { project_id: ids } }
    can %i[read create update soft_delete start complete abort], TestRun, task: { project_id: ids }
    can %i[read create update soft_delete], TestResult, test_case: { task: { project_id: ids } }
    can %i[create destroy], TestStep, test_case: { task: { project_id: ids } }
    can %i[create update destroy], TestStepContent,
        test_step: { test_case: { task: { project_id: ids } } }

    cannot :destroy, [ User, Project ]
    can :read, Notification, category: %w[system info warning]
    can :manage, NotificationRead, user_id: user.id
  end
end
