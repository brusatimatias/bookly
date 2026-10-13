# Team management by the owner: removing members.
class Admin::MembershipsController < Admin::BaseController
  before_action :require_owner
  before_action :set_membership

  def destroy
    @membership.remove!
    redirect_to admin_team_path, notice: t(".removed", name: @membership.user.name), status: :see_other
  rescue Membership::NotRemovable
    redirect_to admin_team_path, alert: t(".owner"), status: :see_other
  end

  private
    def set_membership
      @membership = Current.business.memberships.includes(:user).find(params[:id])
    end
end
