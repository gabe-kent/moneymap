class ReportsController < ApplicationController
  def show
    @report = SpendingReport.new(Current.user).call
  end
end
