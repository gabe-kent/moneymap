class DashboardController < ApplicationController
  def show
    @summary = DashboardSummary.new(Current.user).call
  end
end
