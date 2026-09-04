class HomeController < ApplicationController
  allow_unauthenticated_access only: %i[ index ]

  def index
    return unless authenticated?

    # Transactions is the fallback because it's the one core page no flag gates,
    # so a signed-in user always lands somewhere usable.
    redirect_to feature_enabled?(:dashboard) ? dashboard_path : transactions_path
  end
end
