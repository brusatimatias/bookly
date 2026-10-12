require "rails_helper"

RSpec.describe MailerHelper, type: :helper do
  it "renders a link styled as a button with inline styles" do
    button = helper.email_button("Aceptar", "https://example.com/accept")

    expect(button).to include('href="https://example.com/accept"', "Aceptar", "background:#{MailerHelper::BRAND_COLOR}")
  end
end
