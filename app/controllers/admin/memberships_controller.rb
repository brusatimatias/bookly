# Team management by the owner: changing roles and removing members.
class Admin::MembershipsController < Admin::BaseController
  before_action :require_owner
  before_action :set_membership

  def update
    if @membership.change_role(params.expect(:role))
      redirect_to admin_team_path, notice: t(".changed", name: @membership.user.name, role: Membership.human_attribute_name("role.#{@membership.role}"))
    else
      redirect_to admin_team_path, alert: t(".not_changed")
    end
  end

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
