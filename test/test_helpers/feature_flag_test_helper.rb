module FeatureFlagTestHelper
  # Flags are off unless a test turns them on — same as a fresh production
  # database — so any test touching a gated page has to opt in.
  def enable_feature(key)
    FeatureFlag.find_or_create_by!(key: key.to_s).update!(globally_enabled: true)
  end

  def enable_feature_for(key, user)
    flag = FeatureFlag.find_or_create_by!(key: key.to_s)
    flag.feature_flag_assignments.find_or_create_by!(user: user)
    flag
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include FeatureFlagTestHelper
end
