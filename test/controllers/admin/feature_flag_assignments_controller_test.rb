require "test_helper"

class Admin::FeatureFlagAssignmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @admin.update!(admin: true)
    @target_user = users(:two)
    @flag = FeatureFlag.create!(key: FeatureFlag::REGISTRY.first)
    sign_in_as @admin
  end

  test "create grants the flag to a user found by email" do
    assert_difference -> { @flag.feature_flag_assignments.count }, 1 do
      post admin_feature_flag_assignments_path(@flag), params: { email_address: @target_user.email_address }
    end

    assert_redirected_to admin_feature_flags_path
    assert @flag.users.include?(@target_user)
  end

  test "create with an unknown email does not create an assignment" do
    assert_no_difference -> { FeatureFlagAssignment.count } do
      post admin_feature_flag_assignments_path(@flag), params: { email_address: "nobody@example.com" }
    end

    assert_redirected_to admin_feature_flags_path
  end

  test "destroy revokes the assignment" do
    assignment = @flag.feature_flag_assignments.create!(user: @target_user)

    assert_difference -> { FeatureFlagAssignment.count }, -1 do
      delete admin_feature_flag_assignment_path(@flag, assignment)
    end

    assert_redirected_to admin_feature_flags_path
  end

  test "create is not found for a signed-in non-admin" do
    sign_out
    sign_in_as @target_user

    assert_no_difference -> { FeatureFlagAssignment.count } do
      post admin_feature_flag_assignments_path(@flag), params: { email_address: @target_user.email_address }
    end

    assert_response :not_found
  end
end
