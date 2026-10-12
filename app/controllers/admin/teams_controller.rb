# Members of the business and pending invitations. Only the owner can invite.
class Admin::TeamsController < Admin::BaseController
  before_action :require_manager

  def show
    @memberships = Current.business.memberships.includes(:user).order(:created_at)
    @invitations = Current.business.invitations.pending.includes(:professional).order(:created_at)
  end
end
