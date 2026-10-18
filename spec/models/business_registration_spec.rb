require "rails_helper"

RSpec.describe BusinessRegistration do
  let(:account) { { name: "Lucía Gómez", email_address: "lucia@example.com", password: "password", password_confirmation: "password" } }
  let(:business_attributes) { { business_name: "Barbería Centro", slug: "", time_zone: "America/Argentina/Buenos_Aires", locale: "es", currency: "ARS" } }

  describe "without an account" do
    subject(:registration) { described_class.new(account.merge(business_attributes)) }

    it "creates the owner's account, the business and the owner's membership" do
      expect(registration.save).to be(true)

      expect(registration).to be_new_account
      expect(registration.user).to be_persisted.and(have_attributes(name: "Lucía Gómez", email_address: "lucia@example.com"))
      expect(registration.business).to be_persisted.and(be_active)
      expect(registration.user.membership_for(registration.business)).to be_owner
    end

    it "suggests the web address from the name and starts the contact email as the owner's" do
      registration.save

      expect(registration.business).to have_attributes(slug: "barberia-centro", contact_email: "lucia@example.com",
                                                      time_zone: "America/Argentina/Buenos_Aires", locale: "es", currency: "ARS")
    end

    it "keeps a chosen web address" do
      registration.slug = "centro"
      registration.save

      expect(registration.business.slug).to eq("centro")
    end

    it "saves nothing when the business is invalid" do
      registration.slug = "admin"

      expect { expect(registration.save).to be(false) }.not_to change { [ User.count, Business.count, Membership.count ] }
      expect(registration.errors.full_messages).to eq([ "Dirección web está reservada por el sistema" ])
    end

    it "saves nothing when the account is invalid, and shows both records' errors under the form's names" do
      registration = described_class.new(account.merge(business_attributes).merge(password_confirmation: "other", business_name: ""))

      expect { registration.save }.not_to change { [ User.count, Business.count ] }
      expect(registration.errors).to be_of_kind(:password_confirmation, :confirmation)
      expect(registration.errors).to be_of_kind(:business_name, :blank)
      expect(registration.errors.full_messages).to include("Nombre del negocio no puede estar en blanco")
    end

    it "doesn't complain about the web address when there's no name to suggest it from" do
      registration.business_name = ""
      registration.save

      expect(registration.errors.attribute_names).to eq([ :business_name ])
    end

    it "rejects an email that already has an account" do
      create(:user, email_address: "lucia@example.com")

      expect(registration.save).to be(false)
      expect(registration.errors).to be_of_kind(:email_address, :taken)
    end

    it "rejects a web address already taken" do
      create(:business, slug: "barberia-centro")

      expect(registration.save).to be(false)
      expect(registration.errors).to be_of_kind(:slug, :taken)
    end
  end

  describe "for a signed in user" do
    let(:user) { create(:user, email_address: "martin@example.com") }

    subject(:registration) { described_class.new(business_attributes, user: user) }

    it "adds the business to their account, ignoring the account fields" do
      registration.name = "Someone else"

      expect { expect(registration.save).to be(true) }.not_to change(User, :count)

      expect(registration).not_to be_new_account
      expect(user.membership_for(registration.business)).to be_owner
      expect(registration.business.contact_email).to eq("martin@example.com")
      expect(user.reload.name).not_to eq("Someone else")
    end
  end

  describe "defaults" do
    it "follows the current language and the business's defaults" do
      I18n.with_locale(:en) do
        expect(described_class.new).to have_attributes(locale: "en", time_zone: "America/Argentina/Buenos_Aires", currency: "ARS")
      end
    end
  end
end
