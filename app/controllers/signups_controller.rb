# Signing up a business (/signup). Without an account it creates the owner's
# too; signed in users add the business to theirs. Either way they land in the
# new business's setup assistant, signed in.
class SignupsController < ApplicationController
  layout "auth"
  allow_unauthenticated_access
  before_action :resume_session
  rate_limit to: 10, within: 1.hour, only: :create, with: -> { redirect_to new_signup_path, alert: t("signups.create.rate_limited") }

  def new
    @registration = BusinessRegistration.new(user: Current.user)
  end

  def create
    @registration = BusinessRegistration.new(registration_params, user: Current.user)

    if @registration.save
      start_new_session_for @registration.user if @registration.new_account?
      business = @registration.business
      redirect_to admin_setup_step_path("details", business_slug: business), notice: I18n.with_locale(business.locale) { t(".created", business: business.name) }
    else
      # Signing in with the account that already has the email brings them back here.
      session[:return_to_after_authenticating] = new_signup_url if @registration.errors.of_kind?(:email_address, :taken)
      render :new, status: :unprocessable_entity
    end
  end

  private
    def registration_params
      params.expect(business_registration: %i[name email_address password password_confirmation business_name slug time_zone locale currency])
    end
end
