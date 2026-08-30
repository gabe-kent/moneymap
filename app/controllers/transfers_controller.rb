class TransfersController < ApplicationController
  before_action :set_transfer, only: %i[ edit update destroy ]

  def new
    @transfer = TransferForm.new(occurred_on: Date.current)
  end

  def create
    @transfer = TransferForm.new(transfer_params)

    if @transfer.save(Current.user)
      redirect_to transactions_path, notice: "Transfer created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @transfer.assign_attributes(transfer_params)

    if @transfer.save(Current.user)
      redirect_to transactions_path, notice: "Transfer updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @transfer.destroy(Current.user)
    redirect_to transactions_path, notice: "Transfer deleted.", status: :see_other
  end

  private
    def set_transfer
      @transfer = TransferForm.find(Current.user, params[:id])
    end

    def transfer_params
      params.expect(transfer: [ :from_account_id, :to_account_id, :amount, :occurred_on, :description ])
    end
end
