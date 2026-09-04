require "test_helper"

class FeatureFlagAssignmentTest < ActiveSupport::TestCase
  setup { @flag = FeatureFlag.create!(key: FeatureFlag::REGISTRY.first) }

  test "valid with a flag and a user" do
    assignment = @flag.feature_flag_assignments.build(user: users(:one))
    assert assignment.valid?
  end

  test "invalid with a duplicate user for the same flag" do
    @flag.feature_flag_assignments.create!(user: users(:one))
    duplicate = @flag.feature_flag_assignments.build(user: users(:one))

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "the same user can be assigned to a different flag" do
    other_key = FeatureFlag::REGISTRY.second || raise("REGISTRY needs 2+ keys for this test")
    other_flag = FeatureFlag.create!(key: other_key)
    @flag.feature_flag_assignments.create!(user: users(:one))

    assignment = other_flag.feature_flag_assignments.build(user: users(:one))
    assert assignment.valid?
  end
end
