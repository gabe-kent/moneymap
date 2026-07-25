class AccountsController < ApplicationController
  before_action :set_account, only: %i[ edit update destroy ]

  def index
    @accounts = Current.user.accounts.order(:name)
  end

  def new
    @account = Current.user.accounts.build
  end

  def create
    @account = Current.user.accounts.build(account_params)

    if @account.save
      redirect_to accounts_path, notice: "Account created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @account.update(account_params)
      redirect_to accounts_path, notice: "Account updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @account.destroy
    redirect_to accounts_path, notice: "Account deleted.", status: :see_other
  end

  private
    def set_account
      @account = Current.user.accounts.find(params[:id])
    end

    def account_params
      params.expect(account: [ :name, :kind, :starting_balance ])
    end
end
