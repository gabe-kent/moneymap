class ReportsController < ApplicationController
  gate_behind :reports

  def show
    @report = SpendingReport.new(Current.user).call
  end
end
