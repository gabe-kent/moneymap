class SettingsController < ApplicationController
  def edit
    @user = Current.user
    @sessions = Current.user.sessions.order(created_at: :desc)
  end

  def update
    @user = Current.user

    if @user.authenticate(params[:current_password])
      if @user.update(password_params)
        redirect_to edit_settings_path, notice: "Password updated."
      else
        @sessions = Current.user.sessions.order(created_at: :desc)
        render :edit, status: :unprocessable_entity
      end
    else
      @sessions = Current.user.sessions.order(created_at: :desc)
      @user.errors.add(:current_password, "is incorrect")
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def password_params
      params.permit(:password, :password_confirmation)
    end
end
