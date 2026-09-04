class BudgetsController < ApplicationController
  gate_behind :budgets
  before_action :set_month, only: %i[ index ]
  before_action :set_budget, only: %i[ edit update destroy ]

  def index
    @overview = BudgetOverview.new(Current.user, month: @month).call
  end

  def new
    @budget = Current.user.budgets.build(month: month_param || Date.current)
  end

  def create
    @budget = Current.user.budgets.build(budget_params)

    if @budget.save
      redirect_to budgets_path(month: @budget.month), notice: "Budget created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @budget.update(budget_params)
      redirect_to budgets_path(month: @budget.month), notice: "Budget updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @budget.destroy
    redirect_to budgets_path(month: @budget.month), notice: "Budget deleted.", status: :see_other
  end

  private
    def set_month
      @month = month_param || Date.current.beginning_of_month
    end

    def set_budget
      @budget = Current.user.budgets.find(params[:id])
    end

    # `?month=` is a date string; anything unparseable falls back to the caller's
    # default rather than raising on a hand-edited URL.
    def month_param
      return if params[:month].blank?
      Date.parse(params[:month]).beginning_of_month
    rescue Date::Error
      nil
    end

    def budget_params
      params.expect(budget: [ :category_id, :month, :target ])
    end
end
