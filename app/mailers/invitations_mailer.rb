class InvitationsMailer < ApplicationMailer
  # Written in the business's language, whatever the locale of the sender.
  def invite(invitation)
    @invitation = invitation
    @business = invitation.business

    I18n.with_locale(@business.locale) do
      mail to: invitation.email, subject: t(".subject", business: @business.name)
    end
  end
end
