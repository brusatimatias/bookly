class Admin::InvitationsController < Admin::BaseController
  before_action :require_owner
  before_action :set_invitation, only: %i[destroy resend]

  def new
    @invitation = Current.business.invitations.new(role: :professional, professional: find_professional(params[:professional_id]))
  end

  def create
    @invitation = Current.business.invitations.new(invitation_params)
    @invitation.invited_by = Current.user
    @invitation.professional = find_professional(params.dig(:invitation, :professional_id))

    if @invitation.save
      InvitationsMailer.invite(@invitation).deliver_later
      back_to = @invitation.professional ? admin_professionals_path : admin_team_path
      redirect_to back_to, notice: t(".sent", email: @invitation.email)
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

    # Inviting from a profile without an account; only this business's profiles.
    def find_professional(id)
      Current.business.professionals.find(id) if id.present?
    end

    def invitation_params
      params.expect(invitation: %i[email role])
    end
end
