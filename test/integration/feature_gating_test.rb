require "test_helper"

# The dashboard, budgets and reports pages ship behind flags. Flags are off by
# default (FeatureFlagCheck returns false when no row exists), so these assert
# both directions for each gate.
class FeatureGatingTest < ActionDispatch::IntegrationTest
  GATES = {
    dashboard: "/dashboard",
    budgets: "/budgets",
    reports: "/reports"
  }.freeze

  setup do
    @user = users(:one)
    @other_user = users(:two)
  end

  GATES.each do |key, path|
    test "#{key} is hidden when its flag is off" do
      sign_in_as @user

      get path

      assert_response :not_found
    end

    test "#{key} is reachable when its flag is globally enabled" do
      enable_feature key
      sign_in_as @user

      get path

      assert_response :success
    end

    test "#{key} is reachable for a user it is individually assigned to" do
      enable_feature_for key, @user
      sign_in_as @user

      get path

      assert_response :success
    end

    test "#{key} stays hidden from a user without that individual assignment" do
      enable_feature_for key, @other_user
      sign_in_as @user

      get path

      assert_response :not_found
    end

    test "#{key} asks for sign-in before it reports being gated" do
      get path

      assert_redirected_to new_session_path
    end
  end

  test "gating covers a section's nested actions too, not just its index" do
    sign_in_as @user

    get new_budget_path
    assert_response :not_found

    post budgets_path, params: { budget: { category_id: 1, month: Date.current, target: "10.00" } }
    assert_response :not_found
  end

  test "one flag being on does not open the others" do
    enable_feature :budgets
    sign_in_as @user

    get "/budgets"
    assert_response :success

    get "/dashboard"
    assert_response :not_found
  end

  test "the sidebar drops sections whose flag is off" do
    sign_in_as @user

    get transactions_path

    assert_response :success
    assert_select "aside a[href=?]", transactions_path, count: 1
    [ dashboard_path, budgets_path, reports_path ].each do |path|
      assert_select "aside a[href=?]", path, { count: 0 }, "expected the sidebar to drop #{path}"
    end
  end

  test "the sidebar shows a section once its flag is on" do
    enable_feature :reports
    sign_in_as @user

    get transactions_path

    assert_select "aside a[href=?]", reports_path, count: 1
    assert_select "aside a[href=?]", dashboard_path, count: 0
  end

  test "root sends a signed-in user to transactions while the dashboard is gated" do
    sign_in_as @user

    get root_path

    assert_redirected_to transactions_path
  end

  test "root sends a signed-in user to the dashboard once it is enabled" do
    enable_feature :dashboard
    sign_in_as @user

    get root_path

    assert_redirected_to dashboard_path
  end

  test "reports is a registered flag key" do
    assert_includes FeatureFlag::REGISTRY, "reports"
    assert FeatureFlag.new(key: "reports").valid?
  end
end
