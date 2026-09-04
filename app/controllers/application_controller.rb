class ApplicationController < ActionController::Base
  include Authentication
  include FeatureGated
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :feature_enabled?

  private
    # Memoized per request because the sidebar asks about every gated section on
    # each render. Resolution itself stays in FeatureFlagCheck rather than being
    # reimplemented here for fewer queries.
    def feature_enabled?(key)
      @feature_enabled ||= {}
      @feature_enabled.fetch(key.to_s) do
        @feature_enabled[key.to_s] = FeatureFlag.enabled?(key, user: Current.user)
      end
    end
end
