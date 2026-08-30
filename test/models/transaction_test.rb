require "test_helper"

class TransactionTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @account = @user.accounts.create!(name: "Checking", kind: "checking")
    @category = @user.categories.create!(name: "Groceries", kind: "expense", color: "orange")
    @income_category = @user.categories.create!(name: "Salary", kind: "income", color: "green")
  end

  test "valid with account, category, amount, occurred_on, and txn_type" do
    transaction = @user.transactions.build(account: @account, category: @category, amount_cents: 4500, occurred_on: Date.current, txn_type: "expense")
    assert transaction.valid?
  end

  test "invalid without occurred_on" do
    transaction = @user.transactions.build(account: @account, category: @category, amount_cents: 4500, txn_type: "expense")
    assert_not transaction.valid?
    assert_includes transaction.errors[:occurred_on], "can't be blank"
  end

  test "invalid without txn_type" do
    transaction = @user.transactions.build(account: @account, category: @category, amount_cents: 4500, occurred_on: Date.current)
    assert_not transaction.valid?
    assert_includes transaction.errors[:txn_type], "can't be blank"
  end

  test "raises on a txn_type outside the fixed list" do
    transaction = @user.transactions.build(account: @account, category: @category, amount_cents: 4500, occurred_on: Date.current)
    assert_raises(ArgumentError) { transaction.txn_type = "bitcoin" }
  end

  test "forces a positive amount for income regardless of submitted sign" do
    transaction = @user.transactions.create!(account: @account, category: @income_category, amount_cents: -5000, occurred_on: Date.current, txn_type: "income")
    assert_equal 5000, transaction.amount_cents
  end

  test "forces a negative amount for expense regardless of submitted sign" do
    transaction = @user.transactions.create!(account: @account, category: @category, amount_cents: 4500, occurred_on: Date.current, txn_type: "expense")
    assert_equal(-4500, transaction.amount_cents)
  end

  test "amount is monetized in USD" do
    transaction = @user.transactions.create!(account: @account, category: @category, amount_cents: 4500, occurred_on: Date.current, txn_type: "expense")
    assert_equal Money.new(-4500, "USD"), transaction.amount
  end

  test "invalid with an account belonging to another user" do
    other_account = users(:two).accounts.create!(name: "Their Checking", kind: "checking")
    transaction = @user.transactions.build(account: other_account, category: @category, amount_cents: 4500, occurred_on: Date.current, txn_type: "expense")

    assert_not transaction.valid?
    assert_includes transaction.errors[:account], "must belong to you"
  end

  test "invalid with a category belonging to another user" do
    other_category = users(:two).categories.create!(name: "Their Groceries", kind: "expense", color: "orange")
    transaction = @user.transactions.build(account: @account, category: other_category, amount_cents: 4500, occurred_on: Date.current, txn_type: "expense")

    assert_not transaction.valid?
    assert_includes transaction.errors[:category], "must belong to you"
  end

  test "invalid when category kind does not match txn_type" do
    transaction = @user.transactions.build(account: @account, category: @income_category, amount_cents: 4500, occurred_on: Date.current, txn_type: "expense")

    assert_not transaction.valid?
    assert_includes transaction.errors[:category], "kind must match transaction type"
  end

  test "does not apply the sign convention to a transfer with a negative amount" do
    transaction = @user.transactions.create!(account: @account, amount_cents: -5000, occurred_on: Date.current, txn_type: "transfer")
    assert_equal(-5000, transaction.amount_cents)
  end

  test "does not apply the sign convention to a transfer with a positive amount" do
    transaction = @user.transactions.create!(account: @account, amount_cents: 5000, occurred_on: Date.current, txn_type: "transfer")
    assert_equal 5000, transaction.amount_cents
  end

  test "requires a user" do
    transaction = Transaction.new(account: @account, category: @category, amount_cents: 4500, occurred_on: Date.current, txn_type: "expense")
    assert_not transaction.valid?
    assert_includes transaction.errors[:user], "must exist"
  end

  test "destroying a user destroys their transactions" do
    transaction = @user.transactions.create!(account: @account, category: @category, amount_cents: 4500, occurred_on: Date.current, txn_type: "expense")
    assert_difference -> { Transaction.count }, -1 do
      @user.destroy
    end
    assert_not Transaction.exists?(transaction.id)
  end
end
