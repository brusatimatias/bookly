class Admin::InvitationsController < Admin::BaseController
  before_action :require_owner
  before_action :set_invitation, only: %i[destroy resend]

  def new
    @invitation = Current.business.invitations.new(role: :professional)
  end

  def create
    @invitation = Current.business.invitations.new(invitation_params.merge(invited_by: Current.user))

    if @invitation.save
      InvitationsMailer.invite(@invitation).deliver_later
      redirect_to admin_team_path, notice: t(".sent", email: @invitation.email)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def resend
    @invitation.renew!
    InvitationsMailer.invite(@invitation).deliver_later
    redirect_to admin_team_path, notice: t(".sent", email: @invitation.email)
  end

  def destroy
    @invitation.destroy!
    redirect_to admin_team_path, notice: t(".revoked", email: @invitation.email), status: :see_other
  end

  private
    def set_invitation
      @invitation = Current.business.invitations.pending.find(params[:id])
    end

    def invitation_params
      params.expect(invitation: %i[email role])
    end
end
