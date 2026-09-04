module Admin
  class FeatureFlagsController < Admin::BaseController
    def index
      FeatureFlag::REGISTRY.each do |key|
        FeatureFlag.find_or_create_by!(key: key)
      rescue ActiveRecord::RecordNotUnique
        # Another request just created this row (unique index on key) — nothing to do.
      end
      @feature_flags = FeatureFlag.includes(feature_flag_assignments: :user).order(:key)
    end

    def update
      feature_flag = FeatureFlag.find(params[:id])
      feature_flag.update!(globally_enabled: !feature_flag.globally_enabled?)

      redirect_to admin_feature_flags_path,
        notice: "#{feature_flag.key.titleize} #{feature_flag.globally_enabled? ? "enabled" : "disabled"} globally."
    end
  end
end
