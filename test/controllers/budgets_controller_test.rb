require "test_helper"

class BudgetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @category = @user.categories.create!(name: "Groceries", kind: "expense", color: "orange")
    @account = @user.accounts.create!(name: "Checking", kind: "checking", starting_balance_cents: 100_000)
    sign_in_as @user
  end

  test "requires authentication" do
    sign_out
    get budgets_path
    assert_redirected_to new_session_path
  end

  test "index shows the empty state with no budgets" do
    get budgets_path

    assert_response :success
    assert_includes response.body, "No budgets for #{Date.current.strftime('%B %Y')}"
  end

  test "index tracks spend against the target for the current month" do
    @user.budgets.create!(category: @category, month: Date.current, target_cents: 30_000)
    @user.transactions.create!(account: @account, category: @category, amount_cents: 12_000, occurred_on: Date.current, txn_type: "expense")

    get budgets_path

    assert_response :success
    assert_includes response.body, "$120.00"
    assert_includes response.body, "$180.00 left"
    assert_includes response.body, "On track"
  end

  test "index flags a category that is over budget" do
    @user.budgets.create!(category: @category, month: Date.current, target_cents: 10_000)
    @user.transactions.create!(account: @account, category: @category, amount_cents: 15_000, occurred_on: Date.current, txn_type: "expense")

    get budgets_path

    assert_response :success
    assert_includes response.body, "Over budget"
    assert_includes response.body, "$50.00 over"
  end

  test "index honours the month parameter" do
    @user.budgets.create!(category: @category, month: 1.month.ago.to_date, target_cents: 30_000)

    get budgets_path(month: 1.month.ago.to_date)

    assert_response :success
    assert_includes response.body, 1.month.ago.to_date.strftime("%B %Y")
  end

  test "index falls back to the current month for an unparseable month" do
    get budgets_path(month: "not-a-date")

    assert_response :success
    assert_includes response.body, Date.current.strftime("%B %Y")
  end

  test "create adds a budget" do
    assert_difference -> { @user.budgets.count }, 1 do
      post budgets_path, params: { budget: { category_id: @category.id, month: Date.current.beginning_of_month, target: "300.00" } }
    end

    assert_redirected_to budgets_path(month: Date.current.beginning_of_month)
    assert_equal 30_000, @user.budgets.last.target_cents
  end

  test "create with an invalid target re-renders the form" do
    assert_no_difference -> { Budget.count } do
      post budgets_path, params: { budget: { category_id: @category.id, month: Date.current.beginning_of_month, target: "0" } }
    end

    assert_response :unprocessable_entity
  end

  test "create with another user's category re-renders the form" do
    theirs = @other_user.categories.create!(name: "Theirs", kind: "expense", color: "red")

    assert_no_difference -> { Budget.count } do
      post budgets_path, params: { budget: { category_id: theirs.id, month: Date.current.beginning_of_month, target: "300.00" } }
    end

    assert_response :unprocessable_entity
  end

  test "update changes the target" do
    budget = @user.budgets.create!(category: @category, month: Date.current, target_cents: 30_000)

    patch budget_path(budget), params: { budget: { category_id: @category.id, month: budget.month, target: "450.00" } }

    assert_redirected_to budgets_path(month: budget.month)
    assert_equal 45_000, budget.reload.target_cents
  end

  test "destroy removes the budget" do
    budget = @user.budgets.create!(category: @category, month: Date.current, target_cents: 30_000)

    assert_difference -> { @user.budgets.count }, -1 do
      delete budget_path(budget)
    end

    assert_redirected_to budgets_path(month: budget.month)
  end

  test "cannot touch another user's budget" do
    theirs = @other_user.categories.create!(name: "Theirs", kind: "expense", color: "red")
    budget = @other_user.budgets.create!(category: theirs, month: Date.current, target_cents: 30_000)

    get edit_budget_path(budget)

    assert_response :not_found
  end
end
