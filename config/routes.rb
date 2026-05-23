Rails.application.routes.draw do
  get "dashboards/index"
  # Action Cable
  mount ActionCable.server => '/cable'

  # === External webhooks (no Devise session, HMAC-authenticated) ===
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      post 'github_webhooks/ci_result', to: 'github_webhooks#ci_result'
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Root
  root 'dashboard#index'

  # Devise routes for User authentication (must be BEFORE resources :users to avoid conflict)
  devise_for :users, path: '', path_names: {
    sign_in: 'login',
    sign_out: 'logout',
    sign_up: 'register'
  }

  # Dashboard
  get 'dashboard', to: 'dashboard#index'
  get 'admin/dashboard', to: 'dashboard#admin', as: :admin_dashboard
  get 'user/dashboard', to: 'dashboard#user', as: :user_dashboard
  get 'profile/password', to: 'profiles#edit_password', as: :edit_password
  patch 'profile/password', to: 'profiles#update_password', as: :update_password

  # Main resources
  resources :users do
    member do
      patch :soft_delete
    end
  end

  resources :projects do
    collection do
      get :archived
    end
    member do
      patch :soft_delete
      patch :restore
      get :dashboard, to: 'dashboards#project_dashboard'
    end
    resources :daily_import_runs, only: [ :index, :show ]
    get  'redmine_issues',                  to: 'tasks/redmine_issues#index'
    get  'redmine_issues/projects',         to: 'tasks/redmine_issues#projects'
    post 'redmine_issues/import_one',       to: 'tasks/redmine_issues#import_one'
    post 'redmine_issues/import_url',       to: 'tasks/redmine_issues#import_url'
    post 'redmine_issues/import_selected',  to: 'tasks/redmine_issues#import_selected'
    resources :tasks do
      member do
        patch :soft_delete
        patch :restore
        post :create_subtask
        post :promote_to_subtask
        post :promote_all_to_subtask
        post :update_device_config
      end
      resources :test_cases do
        member do
          patch :soft_delete
          patch :restore
          get :cell_history
          post :revert
          post :clone
        end
        collection do
          post :import_from_sheet
          post :clone_bulk
        end
        resources :test_steps, only: [ :create, :destroy ]
        resources :test_results, only: [ :new, :create, :edit, :update, :destroy ] do
          member do
            patch :soft_delete
          end
        end
      end
      resources :bugs do
        member do
          patch :soft_delete
          patch :restore
          get :cell_history
          post :revert
        end
        collection do
          post :import_from_sheet
        end
      end
      resources :test_runs, except: [ :index ] do
        member do
          patch :soft_delete
          post :start
          post :complete
          post :abort
        end
      end
    end
  end

  # Standalone resources (for index pages with filters)
  resources :tasks, only: [ :index ]
  resources :bugs, only: [ :index ]
  resources :test_runs, only: [ :index ]

  # Test results (index, show, soft_delete)
  resources :test_results do
    member do
      patch :soft_delete
    end
  end

  # Test steps and contents
  resources :test_steps, shallow: true do
    resources :test_step_contents, only: [ :update ]
  end

  # Histories (read-only)
  resources :project_histories, only: [ :index, :show ]

  # Background import status (manual + Redmine bulk)
  resources :import_runs, only: [ :show ] do
    member do
      get :status
    end
  end
  resource :app_configuration, only: [ :edit, :update ]

  # Smoke-test routes for error notification. Remove before production deploy.
  if Rails.env.development?
    get "_test/error",     to: ->(_env) { raise StandardError, "Test error at #{Time.current}" }
    get "_test/error_404", to: ->(_env) { raise ActiveRecord::RecordNotFound, "Should be IGNORED" }
    get "_test/error_dup", to: ->(_env) { raise RuntimeError, "Duplicate error message" }
    get "_test/error_job", to: ->(_env) { TestErrorJob.perform_later; [200, { "content-type" => "text/plain" }, ["Job enqueued"]] }
  end

  # Global notifications (header dropdown)
  resources :notifications, only: [ :index ] do
    collection do
      get :unread_count
      post :mark_all_read
    end
    member do
      get :read_and_go
      post :mark_read
    end
  end
end
