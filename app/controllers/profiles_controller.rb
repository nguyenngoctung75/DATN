class ProfilesController < ApplicationController
  def edit_password
    @user = current_user
  end

  def update_password
    @user = current_user

    if @user.valid_password?(user_params[:current_password])
      if @user.update(password: user_params[:password], password_confirmation: user_params[:password_confirmation])
        # Sign in the user by passing validation in case their password changed
        bypass_sign_in(@user)
        redirect_to root_path, notice: 'Password has been changed successfully.'
      else
        render :edit_password, status: :unprocessable_entity
      end
    else
      @user.errors.add(:current_password, 'is incorrect')
      render :edit_password, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end
end
