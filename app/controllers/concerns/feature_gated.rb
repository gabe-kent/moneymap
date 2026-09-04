# Hides a controller behind a feature flag.
#
# A gated action responds 404 rather than redirecting or explaining itself, so a
# flag that's off doesn't advertise the feature — same treatment
# `AdminAuthorization` gives a non-admin.
module FeatureGated
  extend ActiveSupport::Concern

  class_methods do
    def gate_behind(key, **options)
      before_action(**options) do
        head :not_found unless feature_enabled?(key)
      end
    end
  end
end
