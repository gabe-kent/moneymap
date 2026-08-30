require "test_helper"

class TransfersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @checking = @user.accounts.create!(name: "Checking", kind: "checking")
    @savings = @user.accounts.create!(name: "Savings", kind: "savings")
    sign_in_as @user
  end

  test "new renders the form" do
    get new_transfer_path
    assert_response :success
  end

  test "create with valid params creates two linked transactions" do
    assert_difference -> { @user.transactions.count }, 2 do
      post transfers_path, params: { transfer: { from_account_id: @checking.id, to_account_id: @savings.id, amount: "50.00", occurred_on: Date.current } }
    end

    assert_redirected_to transactions_path
    assert_equal(-5000, @checking.transactions.last.amount_cents)
    assert_equal 5000, @savings.transactions.last.amount_cents
  end

  test "create with the same from and to account re-renders the form" do
    assert_no_difference -> { Transaction.count } do
      post transfers_path, params: { transfer: { from_account_id: @checking.id, to_account_id: @checking.id, amount: "50.00", occurred_on: Date.current } }
    end

    assert_response :unprocessable_entity
  end

  test "create with another user's account re-renders the form" do
    other_account = @other_user.accounts.create!(name: "Their Checking", kind: "checking")

    assert_no_difference -> { Transaction.count } do
      post transfers_path, params: { transfer: { from_account_id: @checking.id, to_account_id: other_account.id, amount: "50.00", occurred_on: Date.current } }
    end

    assert_response :unprocessable_entity
  end

  test "edit renders the form for the current user's transfer" do
    form = TransferForm.new(from_account_id: @checking.id, to_account_id: @savings.id, amount: "50.00", occurred_on: Date.current)
    form.save(@user)

    get edit_transfer_path(form.id)
    assert_response :success
  end

  test "edit on another user's transfer is not found" do
    other_checking = @other_user.accounts.create!(name: "Their Checking", kind: "checking")
    other_savings = @other_user.accounts.create!(name: "Their Savings", kind: "savings")
    other_form = TransferForm.new(from_account_id: other_checking.id, to_account_id: other_savings.id, amount: "50.00", occurred_on: Date.current)
    other_form.save(@other_user)

    get edit_transfer_path(other_form.id)

    assert_response :not_found
  end

  test "update replaces both legs" do
    form = TransferForm.new(from_account_id: @checking.id, to_account_id: @savings.id, amount: "50.00", occurred_on: Date.current)
    form.save(@user)

    patch transfer_path(form.id), params: { transfer: { from_account_id: @checking.id, to_account_id: @savings.id, amount: "75.00", occurred_on: Date.current } }

    assert_redirected_to transactions_path
    assert_equal(-7500, @checking.transactions.last.amount_cents)
    assert_equal 7500, @savings.transactions.last.amount_cents
  end

  test "update on another user's transfer is not found" do
    other_checking = @other_user.accounts.create!(name: "Their Checking", kind: "checking")
    other_savings = @other_user.accounts.create!(name: "Their Savings", kind: "savings")
    other_form = TransferForm.new(from_account_id: other_checking.id, to_account_id: other_savings.id, amount: "50.00", occurred_on: Date.current)
    other_form.save(@other_user)

    patch transfer_path(other_form.id), params: { transfer: { from_account_id: other_checking.id, to_account_id: other_savings.id, amount: "999.00", occurred_on: Date.current } }

    assert_response :not_found
  end

  test "destroy removes both legs" do
    form = TransferForm.new(from_account_id: @checking.id, to_account_id: @savings.id, amount: "50.00", occurred_on: Date.current)
    form.save(@user)

    assert_difference -> { Transaction.count }, -2 do
      delete transfer_path(form.id)
    end

    assert_redirected_to transactions_path
  end

  test "destroy on another user's transfer is not found" do
    other_checking = @other_user.accounts.create!(name: "Their Checking", kind: "checking")
    other_savings = @other_user.accounts.create!(name: "Their Savings", kind: "savings")
    other_form = TransferForm.new(from_account_id: other_checking.id, to_account_id: other_savings.id, amount: "50.00", occurred_on: Date.current)
    other_form.save(@other_user)

    assert_no_difference -> { Transaction.count } do
      delete transfer_path(other_form.id)
    end

    assert_response :not_found
  end
end
