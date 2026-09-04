require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    enable_feature :reports
  end

  test "requires authentication" do
    get reports_path
    assert_redirected_to new_session_path
  end

  test "renders with no data at all" do
    sign_in_as @user

    get reports_path

    assert_response :success
    assert_includes response.body, "No spending recorded in this range."
  end

  test "reports the user's spending sources and breakdown" do
    account = @user.accounts.create!(name: "Checking", kind: "checking", starting_balance_cents: 500_000)
    groceries = @user.categories.create!(name: "Groceries", kind: "expense", color: "orange")
    2.times do
      @user.transactions.create!(account: account, category: groceries, amount_cents: 6_000, occurred_on: 1.month.ago.to_date, txn_type: "expense", description: "Corner Store")
    end
    sign_in_as @user

    get reports_path

    assert_response :success
    assert_includes response.body, "Corner Store"
    assert_includes response.body, "2×"
    assert_includes response.body, "$120.00"
  end

  test "does not leak another user's spending" do
    account = @other_user.accounts.create!(name: "Their Checking", kind: "checking")
    category = @other_user.categories.create!(name: "Theirs", kind: "expense", color: "red")
    @other_user.transactions.create!(account: account, category: category, amount_cents: 9_900, occurred_on: 1.month.ago.to_date, txn_type: "expense", description: "Their Merchant")
    sign_in_as @user

    get reports_path

    assert_response :success
    assert_not_includes response.body, "Their Merchant"
  end
end
