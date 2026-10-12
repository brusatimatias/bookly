# Accepting an invitation from the emailed link (/invitations/:token), in the
# business's language. Without an account the person creates one here; with
# one, they sign in with the invited email and then accept.
class InvitationsController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session
  around_action :set_invitation

  def show
    session[:return_to_after_authenticating] = invitation_url(params[:token]) if @existing_user && !authenticated?
  end

  def update
    if @existing_user
      accept_as_existing_user
    else
      accept_as_new_user
    end
  rescue Invitation::NotAcceptable
    render :invalid, status: :not_found
  end

  private
    def set_invitation(&action)
      @invitation = Invitation.find_by_token_for(:acceptance, params[:token])
      return render(:invalid, status: :not_found) unless @invitation

      @business = @invitation.business
      @existing_user = User.find_by(email_address: @invitation.email)

      I18n.with_locale(@business.locale) do
        if @business.suspended?
          render "businesses/unavailable", status: :service_unavailable
        elsif @invitation.expired?
          render :expired, status: :gone
        else
          action.call
        end
      end
    end

    def accept_as_existing_user
      if Current.user == @existing_user
        @invitation.accept!(@existing_user)
        redirect_to_business
      else
        redirect_to invitation_path(params[:token])
      end
    end

    def accept_as_new_user
      return redirect_to(invitation_path(params[:token])) if authenticated?

      @user = User.new(new_user_params.merge(email_address: @invitation.email))

      User.transaction do
        @user.save!
        @invitation.accept!(@user)
      end

      start_new_session_for @user
      redirect_to_business
    rescue ActiveRecord::RecordInvalid
      render :show, status: :unprocessable_entity
    end

    def redirect_to_business
      redirect_to admin_root_path(business_slug: @business.slug), notice: t("invitations.accepted", business: @business.name)
    end

    def new_user_params
      params.expect(user: %i[name password password_confirmation])
    end

    def locale_switchable?
      false
    end
end
