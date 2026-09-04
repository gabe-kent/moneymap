require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
  end

  test "requires authentication" do
    get dashboard_path
    assert_redirected_to new_session_path
  end

  test "shows the empty state when the user has no accounts" do
    sign_in_as @user

    get dashboard_path

    assert_response :success
    assert_includes response.body, "No accounts yet"
  end

  test "renders balances, insights and recent activity for the signed-in user" do
    account = @user.accounts.create!(name: "Everyday Checking", kind: "checking", starting_balance_cents: 100_000)
    salary = @user.categories.create!(name: "Salary", kind: "income", color: "green")
    @user.transactions.create!(account: account, category: salary, amount_cents: 50_000, occurred_on: 1.month.ago.to_date, txn_type: "income", description: "Paycheck")
    sign_in_as @user

    get dashboard_path

    assert_response :success
    assert_includes response.body, "Everyday Checking"
    assert_includes response.body, "Paycheck"
    assert_includes response.body, "$1,500.00" # opening balance plus the paycheck
  end

  test "does not leak another user's accounts" do
    @other_user.accounts.create!(name: "Their Checking", kind: "checking", starting_balance_cents: 100_000)
    @user.accounts.create!(name: "My Checking", kind: "checking", starting_balance_cents: 100_000)
    sign_in_as @user

    get dashboard_path

    assert_response :success
    assert_includes response.body, "My Checking"
    assert_not_includes response.body, "Their Checking"
  end

  test "root redirects to the dashboard once signed in" do
    sign_in_as @user

    get root_path

    assert_redirected_to dashboard_path
  end
end
