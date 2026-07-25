require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @account = @user.accounts.create!(name: "Checking", kind: "checking", starting_balance_cents: 10_000)
    sign_in_as @user
  end

  test "index lists only the current user's accounts" do
    other_account = @other_user.accounts.create!(name: "Their Savings", kind: "savings")

    get accounts_path

    assert_response :success
    assert_includes response.body, @account.name
    assert_not_includes response.body, other_account.name
  end

  test "new renders the form" do
    get new_account_path
    assert_response :success
  end

  test "create with valid params" do
    assert_difference -> { @user.accounts.count }, 1 do
      post accounts_path, params: { account: { name: "Savings", kind: "savings", starting_balance: "5.00" } }
    end

    assert_redirected_to accounts_path
    assert_equal 500, @user.accounts.order(:created_at).last.starting_balance_cents
  end

  test "create with invalid params re-renders the form" do
    assert_no_difference -> { Account.count } do
      post accounts_path, params: { account: { name: "", kind: "savings" } }
    end

    assert_response :unprocessable_entity
  end

  test "edit renders the form for the current user's account" do
    get edit_account_path(@account)
    assert_response :success
  end

  test "edit on another user's account is not found" do
    other_account = @other_user.accounts.create!(name: "Their Checking", kind: "checking")

    get edit_account_path(other_account)

    assert_response :not_found
  end

  test "update with valid params" do
    patch account_path(@account), params: { account: { name: "Updated Name" } }

    assert_redirected_to accounts_path
    assert_equal "Updated Name", @account.reload.name
  end

  test "update on another user's account is not found" do
    other_account = @other_user.accounts.create!(name: "Their Checking", kind: "checking")

    patch account_path(other_account), params: { account: { name: "Hijacked" } }

    assert_response :not_found
    assert_not_equal "Hijacked", other_account.reload.name
  end

  test "destroy removes the account" do
    assert_difference -> { Account.count }, -1 do
      delete account_path(@account)
    end

    assert_redirected_to accounts_path
  end

  test "destroy on another user's account is not found" do
    other_account = @other_user.accounts.create!(name: "Their Checking", kind: "checking")

    assert_no_difference -> { Account.count } do
      delete account_path(other_account)
    end

    assert_response :not_found
  end
end
