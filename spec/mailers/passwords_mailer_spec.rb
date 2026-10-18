require "rails_helper"

RSpec.describe PasswordsMailer, type: :mailer do
  let(:user) { create(:user, name: "Ana", email_address: "ana@example.com") }

  it "sends the reset link to the user" do
    mail = described_class.reset(user)

    expect(mail.to).to eq([ "ana@example.com" ])
    expect(mail.subject).to eq("Restablecé tu contraseña")
    expect(mail.text_part.body.to_s).to include("Hola, Ana:", "/passwords/", "/edit")
  end

  it "is written in the current locale" do
    mail = I18n.with_locale(:en) { described_class.reset(user).message }

    expect(mail.subject).to eq("Reset your password")
    expect(mail.text_part.body.to_s).to include("Hi Ana,")
  end
end
