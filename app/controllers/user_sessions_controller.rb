class UserSessionsController < ApplicationController
  before_action :set_session, only: :destroy

  def destroy
    if @session == Current.session
      terminate_session
      redirect_to new_session_path, notice: "Signed out.", status: :see_other
    else
      @session.destroy
      redirect_to edit_settings_path, notice: "Signed out of that session.", status: :see_other
    end
  end

  def destroy_all
    Current.user.sessions.where.not(id: Current.session.id).destroy_all
    redirect_to edit_settings_path, notice: "Signed out of all other sessions.", status: :see_other
  end

  private
    def set_session
      @session = Current.user.sessions.find(params[:id])
    end
end
