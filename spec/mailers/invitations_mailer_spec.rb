require "rails_helper"

RSpec.describe InvitationsMailer, type: :mailer do
  let(:inviter) { create(:user, name: "Lucía") }

  it "invites with an acceptance link" do
    business = create(:business, name: "Barbería Centro")
    invitation = create(:invitation, business: business, invited_by: inviter, email: "ana@example.com", role: :admin)

    mail = described_class.invite(invitation)

    expect(mail.to).to eq([ "ana@example.com" ])
    expect(mail.subject).to eq("Te invitaron a sumarte a Barbería Centro en Bookly")
    expect(mail.text_part.body.to_s).to include("Lucía te invitó a sumarte a Barbería Centro como administrador.")

    token = mail.text_part.body.to_s[%r{/invitations/([^\s]+)}, 1]
    expect(Invitation.find_by_token_for(:acceptance, token)).to eq(invitation)
  end

  it "is written in the business language" do
    business = create(:business, name: "Downtown Studio", locale: "en")
    invitation = create(:invitation, business: business, invited_by: inviter)

    mail = I18n.with_locale(:es) { described_class.invite(invitation).message }

    expect(mail.subject).to eq("You've been invited to join Downtown Studio on Bookly")
    expect(mail.text_part.body.to_s).to include("Lucía invited you to join Downtown Studio as professional.")
  end
end
