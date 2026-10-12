# Where users land after signing in: straight into their business panel when
# they belong to a single business, otherwise a list to pick one.
class DashboardsController < ApplicationController
  def show
    @memberships = Current.user.memberships.includes(:business).order("businesses.name")

    if @memberships.one?
      redirect_to admin_root_path(business_slug: @memberships.first.business)
    end
  end
end
