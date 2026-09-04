class TransactionsController < ApplicationController
  before_action :set_transaction, only: %i[ edit update destroy ]

  def index
    @transactions = filtered_transactions
    @categories = Current.user.categories.order(:name)
    @net = Money.new(@transactions.sum(:amount_cents), "USD")
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
    # Search / type / category are all optional and compose; a blank or unknown
    # value for any of them is simply not applied.
    def filtered_transactions
      scope = Current.user.transactions.includes(:account, :category).order(occurred_on: :desc, created_at: :desc)
      scope = scope.where(txn_type: params[:type]) if Transaction.txn_types.key?(params[:type])
      scope = scope.where(category_id: params[:category_id]) if params[:category_id].present?
      scope = scope.where("transactions.description ILIKE ?", "%#{sanitize_sql_like(params[:q])}%") if params[:q].present?
      scope
    end

    def sanitize_sql_like(value)
      ActiveRecord::Base.sanitize_sql_like(value.to_s)
    end

    def set_transaction
      @transaction = Current.user.transactions.find(params[:id])
    end

    def transaction_params
      params.expect(transaction: [ :account_id, :category_id, :amount, :occurred_on, :txn_type, :description ])
    end
end
