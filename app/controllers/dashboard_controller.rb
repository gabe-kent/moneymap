class DashboardController < ApplicationController
  gate_behind :dashboard

  def show
    @summary = DashboardSummary.new(Current.user).call
  end
end
