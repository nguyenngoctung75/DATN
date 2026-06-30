class UsersController < ApplicationController
  before_action :authorize_admin
  before_action :set_user, except: %i[index new create]

  def index
    @users = User.active.order(created_at: :desc)
  end

  def show
    @assigned_tasks_count = @user.assigned_tasks.active.count
    @created_test_cases_count = @user.created_test_cases.active.count
    @tester_bugs_count = @user.tester_bugs.count
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    @user.provider = 'local'

    if @user.save
      redirect_to users_path, notice: 'User created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    params_to_update = user_params
    if params_to_update[:password].blank?
      params_to_update.delete(:password)
      params_to_update.delete(:password_confirmation)
    end

    if @user.update(params_to_update)
      redirect_to @user, notice: 'User updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user.destroy
    redirect_to users_path, notice: 'User deleted successfully.'
  end

  def soft_delete
    @user.soft_delete!
    redirect_to users_path, notice: 'User soft deleted successfully.'
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email, :name, :password, :password_confirmation, :role, :avatar)
  end

  def authorize_admin
    authorize! :manage, User
  end
end
