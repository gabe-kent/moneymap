class TransactionsController < ApplicationController
  before_action :set_transaction, only: %i[ edit update destroy ]

  def index
    @transactions = Current.user.transactions.includes(:account, :category).order(occurred_on: :desc, created_at: :desc)
  end

  def new
    @transaction = Current.user.transactions.build(occurred_on: Date.current)
    @transfer = TransferForm.new(occurred_on: Date.current)
  end

  def create
    @transaction = Current.user.transactions.build(transaction_params)

    if @transaction.save
      redirect_to transactions_path, notice: "Transaction created."
    else
      @transfer = TransferForm.new(occurred_on: Date.current)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    redirect_to edit_transfer_path(@transaction.transfer_id) if @transaction.transfer?
  end

  def update
    if @transaction.update(transaction_params)
      redirect_to transactions_path, notice: "Transaction updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @transaction.transfer?
      TransferForm.find(Current.user, @transaction.transfer_id).destroy(Current.user)
      redirect_to transactions_path, notice: "Transfer deleted.", status: :see_other
    else
      @transaction.destroy
      redirect_to transactions_path, notice: "Transaction deleted.", status: :see_other
    end
  end

  private
    def set_transaction
      @transaction = Current.user.transactions.find(params[:id])
    end

    def transaction_params
      params.expect(transaction: [ :account_id, :category_id, :amount, :occurred_on, :txn_type, :description ])
    end
end
