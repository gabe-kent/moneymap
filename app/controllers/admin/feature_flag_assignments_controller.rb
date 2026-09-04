module Admin
  class FeatureFlagAssignmentsController < Admin::BaseController
    before_action :set_feature_flag

    def create
      user = User.find_by(email_address: params[:email_address].to_s.strip.downcase)

      if user.nil?
        redirect_to admin_feature_flags_path, alert: "No user with that email address."
        return
      end

      @feature_flag.feature_flag_assignments.find_or_create_by!(user: user)
      redirect_to admin_feature_flags_path, notice: "#{user.email_address} enabled for #{@feature_flag.key.titleize}."
    end

    def destroy
      @feature_flag.feature_flag_assignments.find(params[:id]).destroy
      redirect_to admin_feature_flags_path, notice: "Override removed.", status: :see_other
    end

    private
      def set_feature_flag
        @feature_flag = FeatureFlag.find(params[:feature_flag_id])
      end
  end
end
