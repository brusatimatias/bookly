require "rails_helper"

RSpec.describe Business do
  describe "defaults" do
    subject(:business) { described_class.new }

    it "uses the default booking configuration" do
      expect(business).to have_attributes(
        time_zone: "America/Argentina/Buenos_Aires",
        locale: "es",
        currency: "ARS",
        slot_interval_minutes: 30,
        buffer_minutes: 0,
        cancellation_window_hours: 24,
        request_expiration_hours: 24,
        min_booking_notice_hours: 2,
        booking_horizon_days: 60
      )
    end

    it "starts active" do
      expect(business).to be_active
    end
  end

  describe "slug" do
    it "is generated from the name when blank" do
      business = create(:business, name: "Barbería Centro")

      expect(business.slug).to eq("barberia-centro")
    end

    it "keeps an explicit slug" do
      business = create(:business, name: "Barbería Centro", slug: "centro")

      expect(business.slug).to eq("centro")
    end

    it "is normalized" do
      business = build(:business, slug: "  Centro ")

      expect(business.slug).to eq("centro")
    end

    it "must be unique" do
      create(:business, slug: "centro")
      business = build(:business, slug: "centro")

      expect(business).not_to be_valid
      expect(business.errors).to be_of_kind(:slug, :taken)
    end

    it "rejects invalid formats" do
      %w[con_guion_bajo -inicio fin- doble--guion con.punto].each do |slug|
        business = build(:business, slug: slug)

        expect(business).not_to be_valid, "expected #{slug.inspect} to be invalid"
        expect(business.errors).to be_of_kind(:slug, :invalid)
      end
    end

    it "rejects reserved slugs: the app's routes and the subdomains it needs" do
      %w[admin signup www mail].each do |slug|
        business = build(:business, slug: slug)

        expect(business).not_to be_valid
        expect(business.errors).to be_of_kind(:slug, :exclusion)
      end
    end

    it "translates the reserved slug error" do
      business = build(:business, slug: "admin")
      business.validate

      I18n.with_locale(:es) do
        expect(business.errors.full_messages_for(:slug)).to eq([ "Dirección web está reservada por el sistema" ])
      end
    end

    it "is used as the URL param" do
      expect(build(:business, slug: "centro").to_param).to eq("centro")
    end
  end

  describe ".subdomain?" do
    it "accepts what could be a business's slug" do
      expect(described_class.subdomain?("barberia-centro")).to be(true)
    end

    it "rejects the app's own subdomains, nested ones and invalid slugs" do
      expect([ "", "www", "mail", "centro.mail", "Centro", "-centro" ].map { |subdomain| described_class.subdomain?(subdomain) }).to all(be(false))
    end
  end

  describe "validations" do
    it "is valid from the factory" do
      expect(build(:business)).to be_valid
    end

    it "requires a name" do
      business = build(:business, name: nil)

      expect(business).not_to be_valid
      expect(business.errors).to be_of_kind(:name, :blank)
    end

    it "accepts IANA time zones only" do
      expect(build(:business, time_zone: "America/New_York")).to be_valid
      expect(build(:business, time_zone: "Buenos Aires")).not_to be_valid
      expect(build(:business, time_zone: "Mars/Olympus")).not_to be_valid
    end

    it "accepts the available locales only" do
      expect(build(:business, locale: "en")).to be_valid
      expect(build(:business, locale: "fr")).not_to be_valid
    end

    it "checks the contact details" do
      business = build(:business, name: "a" * 101, contact_email: "nope", contact_phone: "1" * 31, address: "a" * 201)

      expect(business).not_to be_valid
      expect(business.errors.attribute_names).to match_array(%i[name contact_email contact_phone address])
      expect(build(:business, contact_email: "", contact_phone: "", address: "")).to be_valid
    end

    it "accepts the listed currencies only" do
      expect(build(:business, currency: "USD")).to be_valid
      expect(build(:business, currency: "XYZ")).not_to be_valid
      expect(build(:business, currency: nil)).not_to be_valid
    end

    it "rejects an unknown status" do
      expect(build(:business, status: "closed")).not_to be_valid
    end

    it "requires positive intervals" do
      business = build(:business, slot_interval_minutes: 0, request_expiration_hours: 0, booking_horizon_days: 0)

      expect(business).not_to be_valid
      expect(business.errors.attribute_names).to include(:slot_interval_minutes, :request_expiration_hours, :booking_horizon_days)
    end

    it "allows zero for buffer, cancellation window and minimum notice" do
      business = build(:business, buffer_minutes: 0, cancellation_window_hours: 0, min_booking_notice_hours: 0)

      expect(business).to be_valid
    end

    it "rejects negative values" do
      business = build(:business, buffer_minutes: -1, cancellation_window_hours: -1, min_booking_notice_hours: -1)

      expect(business).not_to be_valid
      expect(business.errors.attribute_names).to include(:buffer_minutes, :cancellation_window_hours, :min_booking_notice_hours)
    end

    it "caps the booking settings" do
      at_limit = build(:business, **Business::BOOKING_LIMITS)
      over_limit = build(:business, **Business::BOOKING_LIMITS.transform_values(&:succ))

      expect(at_limit).to be_valid
      expect(over_limit).not_to be_valid
      expect(over_limit.errors.attribute_names).to match_array(Business::BOOKING_LIMITS.keys)
    end
  end

  describe "database constraints" do
    let(:business) { create(:business) }

    {
      slug: "Not Valid",
      locale: "fr",
      status: "closed",
      slot_interval_minutes: 0,
      buffer_minutes: -1,
      cancellation_window_hours: -1,
      request_expiration_hours: 0,
      min_booking_notice_hours: -1,
      booking_horizon_days: 0
    }.each do |column, value|
      it "rejects an invalid #{column} even when skipping validations" do
        expect { business.update_column(column, value) }.to raise_error(ActiveRecord::StatementInvalid, /check constraint/)
      end
    end

    it "rejects a duplicated slug even when skipping validations" do
      other = create(:business)

      expect { other.update_column(:slug, business.slug) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "#suspend! and #reactivate!" do
    it "suspends and reactivates the business" do
      business = create(:business)

      freeze_time do
        business.suspend!
        expect(business).to be_suspended
        expect(business.suspended_at).to eq(Time.current)
      end

      business.reactivate!
      expect(business).to be_active
      expect(business.suspended_at).to be_nil
    end
  end
end
