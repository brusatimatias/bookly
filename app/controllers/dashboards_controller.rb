# Where users land after signing in: straight into their business panel when
# they belong to a single business, the platform panel for platform admins
# without one, otherwise a list to pick one.
class DashboardsController < ApplicationController
  def show
    @memberships = Current.user.memberships.includes(:business).order("businesses.name")

    if @memberships.one?
      redirect_to admin_root_path(business_slug: @memberships.first.business)
    elsif @memberships.none? && Current.user.platform_admin?
      redirect_to platform_root_path
    end
  end
end
