require "test_helper"

class Admin::FeatureFlagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @admin.update!(admin: true)
    @non_admin = users(:two)
  end

  test "index redirects to sign in when signed out" do
    get admin_feature_flags_path
    assert_redirected_to new_session_path
  end

  test "index is not found for a signed-in non-admin" do
    sign_in_as @non_admin
    get admin_feature_flags_path
    assert_response :not_found
  end

  test "index lists every registered flag for an admin, creating rows as needed" do
    sign_in_as @admin

    assert_difference -> { FeatureFlag.count }, FeatureFlag::REGISTRY.size do
      get admin_feature_flags_path
    end

    assert_response :success
    FeatureFlag::REGISTRY.each { |key| assert_includes response.body, key }
  end

  test "update toggles globally_enabled" do
    sign_in_as @admin
    flag = FeatureFlag.create!(key: FeatureFlag::REGISTRY.first)

    patch admin_feature_flag_path(flag)
    assert_redirected_to admin_feature_flags_path
    assert flag.reload.globally_enabled?

    patch admin_feature_flag_path(flag)
    assert_not flag.reload.globally_enabled?
  end

  test "update is not found for a signed-in non-admin" do
    sign_in_as @non_admin
    flag = FeatureFlag.create!(key: FeatureFlag::REGISTRY.first)

    patch admin_feature_flag_path(flag)

    assert_response :not_found
    assert_not flag.reload.globally_enabled?
  end
end
