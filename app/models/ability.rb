# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    # Define abilities for the user here. For example:
    #
    #   return unless user.present?
    #   can :read, :all
    #   return unless user.admin?
    #   can :manage, :all
    #
    # The first argument to `can` is the action you are giving the user
    # permission to do.
    # If you pass :manage it will apply to every action. Other common actions
    # here are :read, :create, :update and :destroy.
    #
    # The second argument is the resource the user can perform the action on.
    # If you pass :all it will apply to every resource. Otherwise pass a Ruby
    # class of the resource.
    #
    # The third argument is an optional hash of conditions to further filter the
    # objects.
    # For example, here the user can only update published articles.
    #
    #   can :update, Article, published: true
    #
    # See the wiki for details:
    # https://github.com/CanCanCommunity/cancancan/blob/develop/docs/define_check_abilities.md

    user ||= User.new # guest user (not logged in)

    if user.admin?
      can :manage, :all
    elsif user.user?
      can :read, Project
      can %i[read create update destroy], Task
      can :read, TestCase
      can :read, Bug
      can :read, TestRun
      can :read, TestResult

      can %i[create update clone clone_bulk], TestCase
      can %i[create update], TestRun
      can %i[create update], TestResult
      can %i[create update], Bug
      can %i[create update], BugComment
      can %i[create destroy], TestStep

      can :history, TestCase
      can :history, Bug
      can %i[start complete abort], TestRun

      cannot :destroy, User
      cannot :destroy, Project

      can :read, ImportRun
      can %i[create update destroy], TestStepContent
      can :read, Notification, category: %w[system info warning]
      can :manage, NotificationRead, user_id: user.id
    else
      # Guest user (not logged in) - no permissions
      cannot :manage, :all
    end
  end
end
