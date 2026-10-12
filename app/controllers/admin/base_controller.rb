# Base for the business panel (/:business_slug/admin). Requires a signed in
# member of the business: anyone else gets a 404, so the panel doesn't reveal
# anything about the business. Actions restricted to some roles use
# require_owner or require_manager.
class Admin::BaseController < ApplicationController
  include SetCurrentBusiness

  layout "admin"

  before_action :require_membership

  private
    def require_membership
      Current.membership = Current.user.membership_for(Current.business) || raise(ActiveRecord::RecordNotFound)
    end

    def require_owner
      deny_access unless Current.membership.owner?
    end

    def require_manager
      deny_access unless Current.membership.manager?
    end

    def deny_access
      redirect_to admin_root_path, alert: t("admin.access_denied")
    end

    def default_url_options
      super.merge(business_slug: Current.business&.slug)
    end
end
