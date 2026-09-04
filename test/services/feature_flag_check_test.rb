require "test_helper"

class FeatureFlagCheckTest < ActiveSupport::TestCase
  setup { @key = FeatureFlag::REGISTRY.first }

  test "false when no flag row exists for the key" do
    assert_not FeatureFlagCheck.new(@key, user: users(:one)).call
  end

  test "true when globally enabled, regardless of user" do
    FeatureFlag.create!(key: @key, globally_enabled: true)

    assert FeatureFlagCheck.new(@key, user: users(:one)).call
    assert FeatureFlagCheck.new(@key, user: nil).call
  end

  test "true when not globally enabled but the user has an assignment" do
    flag = FeatureFlag.create!(key: @key, globally_enabled: false)
    flag.feature_flag_assignments.create!(user: users(:one))

    assert FeatureFlagCheck.new(@key, user: users(:one)).call
  end

  test "false when not globally enabled and the user has no assignment" do
    FeatureFlag.create!(key: @key, globally_enabled: false)

    assert_not FeatureFlagCheck.new(@key, user: users(:one)).call
  end

  test "false when not globally enabled and there is no user" do
    FeatureFlag.create!(key: @key, globally_enabled: false)

    assert_not FeatureFlagCheck.new(@key, user: nil).call
  end

  test "accepts the key as a symbol" do
    FeatureFlag.create!(key: @key, globally_enabled: true)

    assert FeatureFlagCheck.new(@key.to_sym, user: nil).call
  end
end
