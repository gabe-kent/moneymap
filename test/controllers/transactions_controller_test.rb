require "test_helper"

class TransactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @account = @user.accounts.create!(name: "Checking", kind: "checking")
    @category = @user.categories.create!(name: "Groceries", kind: "expense", color: "orange")
    @income_category = @user.categories.create!(name: "Salary", kind: "income", color: "green")
    @transaction = @user.transactions.create!(account: @account, category: @category, amount_cents: 4500, occurred_on: Date.current, txn_type: "expense")
    sign_in_as @user
  end

  test "index lists only the current user's transactions" do
    other_account = @other_user.accounts.create!(name: "Their Checking", kind: "checking")
    other_category = @other_user.categories.create!(name: "Their Groceries", kind: "expense", color: "orange")
    @other_user.transactions.create!(account: other_account, category: other_category, amount_cents: 1000, occurred_on: Date.current, txn_type: "expense")

    get transactions_path

    assert_response :success
    assert_includes response.body, @account.name
    assert_not_includes response.body, other_account.name
  end

  test "index renders successfully when a transfer leg has no category" do
    checking = @user.accounts.create!(name: "Checking 2", kind: "checking")
    savings = @user.accounts.create!(name: "Savings", kind: "savings")
    TransferForm.new(from_account_id: checking.id, to_account_id: savings.id, amount: "50.00", occurred_on: Date.current).save(@user)

    get transactions_path

    assert_response :success
  end

  test "index filters by transaction type" do
    @user.transactions.create!(account: @account, category: @income_category, amount_cents: 90_000, occurred_on: Date.current, txn_type: "income", description: "Paycheck")

    get transactions_path(type: "income")

    assert_response :success
    assert_includes response.body, "Paycheck"
    assert_includes response.body, "1 transaction"
  end

  test "index filters by category" do
    @user.transactions.create!(account: @account, category: @income_category, amount_cents: 90_000, occurred_on: Date.current, txn_type: "income", description: "Paycheck")

    get transactions_path(category_id: @income_category.id)

    assert_response :success
    assert_includes response.body, "Paycheck"
    assert_includes response.body, "1 transaction"
  end

  test "index searches descriptions case-insensitively" do
    @user.transactions.create!(account: @account, category: @category, amount_cents: 2_000, occurred_on: Date.current, txn_type: "expense", description: "Corner Store")

    get transactions_path(q: "corner")

    assert_response :success
    assert_includes response.body, "Corner Store"
    assert_includes response.body, "1 transaction"
  end

  test "index treats search wildcards as literal characters" do
    @user.transactions.create!(account: @account, category: @category, amount_cents: 2_000, occurred_on: Date.current, txn_type: "expense", description: "Corner Store")

    get transactions_path(q: "%")

    assert_response :success
    assert_includes response.body, "0 transactions"
  end

  test "index ignores an unknown type filter" do
    get transactions_path(type: "bogus")

    assert_response :success
    assert_includes response.body, "1 transaction"
  end

  test "new renders the form" do
    get new_transaction_path
    assert_response :success
  end

  test "create with valid params applies the sign convention" do
    assert_difference -> { @user.transactions.count }, 1 do
      post transactions_path, params: { transaction: { account_id: @account.id, category_id: @category.id, amount: "45.00", occurred_on: Date.current, txn_type: "expense" } }
    end

    assert_redirected_to transactions_path
    assert_equal(-4500, @user.transactions.order(:created_at).last.amount_cents)
  end

  test "create with invalid params re-renders the form" do
    assert_no_difference -> { Transaction.count } do
      post transactions_path, params: { transaction: { account_id: @account.id, category_id: @category.id, amount: "45.00", txn_type: "expense" } }
    end

    assert_response :unprocessable_entity
  end

  test "create with another user's account re-renders the form" do
    other_account = @other_user.accounts.create!(name: "Their Checking", kind: "checking")

    assert_no_difference -> { Transaction.count } do
      post transactions_path, params: { transaction: { account_id: other_account.id, category_id: @category.id, amount: "45.00", occurred_on: Date.current, txn_type: "expense" } }
    end

    assert_response :unprocessable_entity
  end

  test "create with a mismatched category kind re-renders the form" do
    assert_no_difference -> { Transaction.count } do
      post transactions_path, params: { transaction: { account_id: @account.id, category_id: @income_category.id, amount: "45.00", occurred_on: Date.current, txn_type: "expense" } }
    end

    assert_response :unprocessable_entity
  end

  test "edit renders the form for the current user's transaction" do
    get edit_transaction_path(@transaction)
    assert_response :success
  end

  test "edit pre-fills an expense's amount as positive, not the signed stored value" do
    get edit_transaction_path(@transaction)

    assert_response :success
    assert_includes response.body, 'value="45.00"'
    assert_not_includes response.body, 'value="-45.00"'
  end

  test "edit on another user's transaction is not found" do
    other_account = @other_user.accounts.create!(name: "Their Checking", kind: "checking")
    other_category = @other_user.categories.create!(name: "Their Groceries", kind: "expense", color: "orange")
    other_transaction = @other_user.transactions.create!(account: other_account, category: other_category, amount_cents: 1000, occurred_on: Date.current, txn_type: "expense")

    get edit_transaction_path(other_transaction)

    assert_response :not_found
  end

  test "update with valid params" do
    patch transaction_path(@transaction), params: { transaction: { description: "Updated" } }

    assert_redirected_to transactions_path
    assert_equal "Updated", @transaction.reload.description
  end

  test "update on another user's transaction is not found" do
    other_account = @other_user.accounts.create!(name: "Their Checking", kind: "checking")
    other_category = @other_user.categories.create!(name: "Their Groceries", kind: "expense", color: "orange")
    other_transaction = @other_user.transactions.create!(account: other_account, category: other_category, amount_cents: 1000, occurred_on: Date.current, txn_type: "expense")

    patch transaction_path(other_transaction), params: { transaction: { description: "Hijacked" } }

    assert_response :not_found
    assert_not_equal "Hijacked", other_transaction.reload.description
  end

  test "destroy removes the transaction" do
    assert_difference -> { Transaction.count }, -1 do
      delete transaction_path(@transaction)
    end

    assert_redirected_to transactions_path
  end

  test "destroy on another user's transaction is not found" do
    other_account = @other_user.accounts.create!(name: "Their Checking", kind: "checking")
    other_category = @other_user.categories.create!(name: "Their Groceries", kind: "expense", color: "orange")
    other_transaction = @other_user.transactions.create!(account: other_account, category: other_category, amount_cents: 1000, occurred_on: Date.current, txn_type: "expense")

    assert_no_difference -> { Transaction.count } do
      delete transaction_path(other_transaction)
    end

    assert_response :not_found
  end

  test "new also builds a transfer form for the page's toggle" do
    get new_transaction_path
    assert_response :success
    assert_includes response.body, "From account"
  end

  test "edit on a transfer redirects to the transfer's edit page" do
    checking = @user.accounts.create!(name: "Checking 2", kind: "checking")
    savings = @user.accounts.create!(name: "Savings", kind: "savings")
    form = TransferForm.new(from_account_id: checking.id, to_account_id: savings.id, amount: "50.00", occurred_on: Date.current)
    form.save(@user)
    transfer_leg = checking.transactions.last

    get edit_transaction_path(transfer_leg)

    assert_redirected_to edit_transfer_path(transfer_leg.transfer_id)
  end

  test "destroy on a transfer leg removes both legs" do
    checking = @user.accounts.create!(name: "Checking 2", kind: "checking")
    savings = @user.accounts.create!(name: "Savings", kind: "savings")
    form = TransferForm.new(from_account_id: checking.id, to_account_id: savings.id, amount: "50.00", occurred_on: Date.current)
    form.save(@user)
    transfer_leg = checking.transactions.last

    assert_difference -> { Transaction.count }, -2 do
      delete transaction_path(transfer_leg)
    end

    assert_redirected_to transactions_path
  end
end
