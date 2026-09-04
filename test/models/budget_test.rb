require "test_helper"

class BudgetTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @category = @user.categories.create!(name: "Groceries", kind: "expense", color: "orange")
  end

  test "normalizes month to the first of the month" do
    budget = @user.budgets.create!(category: @category, month: Date.new(2026, 8, 17), target_cents: 30_000)

    assert_equal Date.new(2026, 8, 1), budget.month
  end

  test "requires a target greater than zero" do
    budget = @user.budgets.build(category: @category, month: Date.current, target_cents: 0)

    assert_not budget.valid?
    assert_includes budget.errors[:target_cents], "must be greater than 0"
  end

  test "allows only one budget per category per month" do
    @user.budgets.create!(category: @category, month: Date.new(2026, 8, 1), target_cents: 30_000)
    duplicate = @user.budgets.build(category: @category, month: Date.new(2026, 8, 29), target_cents: 40_000)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:category_id], "already has a budget this month"
  end

  test "allows the same category in a different month" do
    @user.budgets.create!(category: @category, month: Date.new(2026, 8, 1), target_cents: 30_000)
    next_month = @user.budgets.build(category: @category, month: Date.new(2026, 9, 1), target_cents: 30_000)

    assert next_month.valid?
  end

  test "rejects an income category" do
    salary = @user.categories.create!(name: "Salary", kind: "income", color: "green")
    budget = @user.budgets.build(category: salary, month: Date.current, target_cents: 30_000)

    assert_not budget.valid?
    assert_includes budget.errors[:category], "must be an expense category"
  end

  test "rejects another user's category" do
    theirs = @other_user.categories.create!(name: "Theirs", kind: "expense", color: "red")
    budget = @user.budgets.build(category: theirs, month: Date.current, target_cents: 30_000)

    assert_not budget.valid?
    assert_includes budget.errors[:category], "must belong to you"
  end

  test "for_month matches any date within the month" do
    budget = @user.budgets.create!(category: @category, month: Date.new(2026, 8, 1), target_cents: 30_000)

    assert_includes @user.budgets.for_month(Date.new(2026, 8, 31)), budget
    assert_not_includes @user.budgets.for_month(Date.new(2026, 9, 1)), budget
  end

  test "is destroyed with its category" do
    @user.budgets.create!(category: @category, month: Date.current, target_cents: 30_000)

    assert_difference -> { @user.budgets.count }, -1 do
      @category.destroy
    end
  end
end
