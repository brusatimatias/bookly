class Admin::DashboardsController < Admin::BaseController
  def show
    @members_count = Current.business.memberships.count
    @pending_invitations_count = Current.business.invitations.pending.count
    @active_services_count = Current.business.services.active.count
  end
end
