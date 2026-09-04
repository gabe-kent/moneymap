class FeatureFlagCheck
  def initialize(key, user: nil)
    @key = key.to_s
    @user = user
  end

  def call
    flag = FeatureFlag.find_by(key: @key)
    return false unless flag
    return true if flag.globally_enabled?
    return false unless @user

    flag.feature_flag_assignments.exists?(user_id: @user.id)
  end
end
