module AdminAuthorization
  extend ActiveSupport::Concern

  included do
    before_action :require_admin
  end

  private
    def require_admin
      head :not_found unless Current.user&.admin?
    end
end
