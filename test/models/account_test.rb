require "test_helper"

class AccountTest < ActiveSupport::TestCase
  setup { @user = users(:one) }

  test "valid with name, kind, and user" do
    account = @user.accounts.build(name: "Checking", kind: "checking")
    assert account.valid?
  end

  test "invalid without a name" do
    account = @user.accounts.build(kind: "checking")
    assert_not account.valid?
    assert_includes account.errors[:name], "can't be blank"
  end

  test "invalid without a kind" do
    account = @user.accounts.build(name: "Checking")
    assert_not account.valid?
    assert_includes account.errors[:kind], "can't be blank"
  end

  test "raises on a kind outside the fixed list" do
    account = @user.accounts.build(name: "Checking")
    assert_raises(ArgumentError) { account.kind = "bitcoin" }
  end

  test "defaults starting_balance_cents to zero" do
    account = @user.accounts.create!(name: "Checking", kind: "checking")
    assert_equal 0, account.starting_balance_cents
  end

  test "invalid with an explicit nil starting_balance_cents" do
    account = @user.accounts.build(name: "Checking", kind: "checking", starting_balance_cents: nil)
    assert_not account.valid?
    assert_includes account.errors[:starting_balance_cents], "can't be blank"
  end

  test "starting_balance is monetized in USD" do
    account = @user.accounts.create!(name: "Checking", kind: "checking", starting_balance_cents: 15_000)
    assert_equal Money.new(15_000, "USD"), account.starting_balance
  end

  test "requires a user" do
    account = Account.new(name: "Checking", kind: "checking")
    assert_not account.valid?
    assert_includes account.errors[:user], "must exist"
  end

  test "destroying a user destroys their accounts" do
    account = @user.accounts.create!(name: "Checking", kind: "checking")
    assert_difference -> { Account.count }, -1 do
      @user.destroy
    end
    assert_not Account.exists?(account.id)
  end
end
