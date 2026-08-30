require "test_helper"

class TransferFormTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @checking = @user.accounts.create!(name: "Checking", kind: "checking")
    @savings = @user.accounts.create!(name: "Savings", kind: "savings")
  end

  test "invalid when from and to accounts are the same" do
    form = TransferForm.new(from_account_id: @checking.id, to_account_id: @checking.id, amount: "50.00", occurred_on: Date.current)

    assert_not form.valid?
    assert_includes form.errors[:to_account_id], "must be different from the from account"
  end

  test "invalid with a zero amount" do
    form = TransferForm.new(from_account_id: @checking.id, to_account_id: @savings.id, amount: "0", occurred_on: Date.current)

    assert_not form.valid?
    assert_includes form.errors[:amount], "must be greater than zero"
  end

  test "invalid with a non-numeric amount" do
    form = TransferForm.new(from_account_id: @checking.id, to_account_id: @savings.id, amount: "not a number", occurred_on: Date.current)

    assert_not form.valid?
    assert_includes form.errors[:amount], "must be greater than zero"
  end

  test "invalid without required fields" do
    form = TransferForm.new

    assert_not form.valid?
    assert_includes form.errors[:from_account_id], "can't be blank"
    assert_includes form.errors[:to_account_id], "can't be blank"
    assert_includes form.errors[:amount], "can't be blank"
    assert_includes form.errors[:occurred_on], "can't be blank"
  end

  test "save creates two linked transactions with opposite signs" do
    form = TransferForm.new(from_account_id: @checking.id, to_account_id: @savings.id, amount: "50.00", occurred_on: Date.current, description: "Moving money")

    assert_difference -> { Transaction.count }, 2 do
      assert form.save(@user)
    end

    outgoing = @checking.transactions.last
    incoming = @savings.transactions.last

    assert_equal(-5000, outgoing.amount_cents)
    assert_equal 5000, incoming.amount_cents
    assert_equal "transfer", outgoing.txn_type
    assert_equal "transfer", incoming.txn_type
    assert_nil outgoing.category_id
    assert_nil incoming.category_id
    assert_equal outgoing.transfer_id, incoming.transfer_id
    assert form.persisted?
  end

  test "save with an account belonging to another user fails and surfaces an error" do
    other_account = users(:two).accounts.create!(name: "Their Checking", kind: "checking")
    form = TransferForm.new(from_account_id: @checking.id, to_account_id: other_account.id, amount: "50.00", occurred_on: Date.current)

    assert_no_difference -> { Transaction.count } do
      assert_not form.save(@user)
    end

    assert form.errors[:base].any?
  end

  test "find loads both legs of an existing transfer" do
    form = TransferForm.new(from_account_id: @checking.id, to_account_id: @savings.id, amount: "50.00", occurred_on: Date.current, description: "Moving money")
    form.save(@user)

    loaded = TransferForm.find(@user, form.id)

    assert_equal @checking.id, loaded.from_account_id
    assert_equal @savings.id, loaded.to_account_id
    assert_equal "50.00", loaded.amount
    assert_equal "Moving money", loaded.description
  end

  test "find raises for a transfer_id that does not belong to the user" do
    other_user = users(:two)
    other_checking = other_user.accounts.create!(name: "Their Checking", kind: "checking")
    other_savings = other_user.accounts.create!(name: "Their Savings", kind: "savings")
    form = TransferForm.new(from_account_id: other_checking.id, to_account_id: other_savings.id, amount: "50.00", occurred_on: Date.current)
    form.save(other_user)

    assert_raises(ActiveRecord::RecordNotFound) { TransferForm.find(@user, form.id) }
  end

  test "save on an existing transfer replaces both legs" do
    form = TransferForm.new(from_account_id: @checking.id, to_account_id: @savings.id, amount: "50.00", occurred_on: Date.current)
    form.save(@user)
    original_transfer_id = form.id

    loaded = TransferForm.find(@user, original_transfer_id)
    loaded.amount = "75.00"

    assert_no_difference -> { Transaction.count } do
      assert loaded.save(@user)
    end

    assert_equal original_transfer_id, loaded.id
    assert_equal(-7500, @checking.transactions.last.amount_cents)
    assert_equal 7500, @savings.transactions.last.amount_cents
  end

  test "destroy removes both legs" do
    form = TransferForm.new(from_account_id: @checking.id, to_account_id: @savings.id, amount: "50.00", occurred_on: Date.current)
    form.save(@user)

    assert_difference -> { Transaction.count }, -2 do
      form.destroy(@user)
    end
  end
end
