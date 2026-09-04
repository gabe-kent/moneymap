require "test_helper"

class FeatureFlagTest < ActiveSupport::TestCase
  test "valid with a registered key" do
    flag = FeatureFlag.new(key: FeatureFlag::REGISTRY.first)
    assert flag.valid?
  end

  test "invalid without a key" do
    flag = FeatureFlag.new(key: nil)
    assert_not flag.valid?
    assert_includes flag.errors[:key], "can't be blank"
  end

  test "invalid with a key outside the registry" do
    flag = FeatureFlag.new(key: "not_a_real_flag")
    assert_not flag.valid?
    assert_includes flag.errors[:key], "is not included in the list"
  end

  test "invalid with a duplicate key" do
    FeatureFlag.create!(key: FeatureFlag::REGISTRY.first)
    duplicate = FeatureFlag.new(key: FeatureFlag::REGISTRY.first)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:key], "has already been taken"
  end

  test "defaults to not globally enabled" do
    flag = FeatureFlag.create!(key: FeatureFlag::REGISTRY.first)
    assert_not flag.globally_enabled?
  end

  test "destroying a flag destroys its assignments" do
    flag = FeatureFlag.create!(key: FeatureFlag::REGISTRY.first)
    flag.feature_flag_assignments.create!(user: users(:one))

    assert_difference -> { FeatureFlagAssignment.count }, -1 do
      flag.destroy
    end
  end
end
