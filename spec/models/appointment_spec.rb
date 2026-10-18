require "rails_helper"

RSpec.describe Appointment, type: :model do
  let(:business) { create(:business, buffer_minutes: 5, request_expiration_hours: 24) }
  let(:service) { create(:service, duration_minutes: 45, price_cents: 1_500_00, buffer_minutes: 10) }
  let(:professional) { create(:professional, services: [ service ]) }
  let(:tomorrow_ten) { 1.day.from_now.change(hour: 10) }

  around { |example| with_business(business) { example.run } }

  def appointment(starts_at = tomorrow_ten, **attributes)
    build(:appointment, service: service, professional: professional, starts_at: starts_at, **attributes)
  end

  it "is valid with the factory defaults" do
    expect(build(:appointment)).to be_valid
  end

  it "is pending by default" do
    expect(Appointment.new).to be_pending
  end

  describe "on create" do
    it "takes its end from the service and its break from the service's" do
      created = appointment.tap(&:save!)

      expect(created.ends_at).to eq(tomorrow_ten + 45.minutes)
      expect(created.buffer_ends_at).to eq(tomorrow_ten + 55.minutes)
      expect(created).to have_attributes(price_cents: 1_500_00, buffer_minutes: 10)
    end

    it "falls back to the business's break" do
      service.update!(buffer_minutes: nil)

      expect(appointment.tap(&:save!).buffer_ends_at).to eq(tomorrow_ten + 50.minutes)
    end

    it "keeps its price and break when the service changes" do
      created = appointment.tap(&:save!)

      service.update!(price_cents: 2_000_00, buffer_minutes: 30)

      expect(created.reload).to have_attributes(price_cents: 1_500_00, buffer_minutes: 10)
    end

    it "lets a request expire after the business's expiration time" do
      freeze_time do
        expect(appointment(3.days.from_now).tap(&:save!).request_expires_at).to eq(24.hours.from_now)
      end
    end

    it "never lets a request expire after the appointment" do
      soon = 2.hours.from_now.change(usec: 0)

      expect(appointment(soon).tap(&:save!).request_expires_at).to eq(soon)
    end

    it "doesn't set an expiration for confirmed appointments" do
      expect(appointment(status: :confirmed).tap(&:save!).request_expires_at).to be_nil
    end
  end

  it "moves its end with its start" do
    created = appointment.tap(&:save!)

    created.update!(starts_at: tomorrow_ten + 2.hours)

    expect(created.ends_at).to eq(tomorrow_ten + 2.hours + 45.minutes)
  end

  it "requires a service the professional offers" do
    other_service = create(:service)

    expect(appointment(service: other_service).tap(&:valid?).errors).to be_of_kind(:service, :not_offered)
  end

  it "only takes known statuses, also in the database" do
    created = appointment.tap(&:save!)

    expect(appointment(status: "lost")).not_to be_valid
    expect { created.update_column(:status, "lost") }.to raise_error(ActiveRecord::StatementInvalid, /appointments_status_valid/)
  end

  it "requires an expiration for pending appointments in the database" do
    created = appointment.tap(&:save!)

    expect { created.update_column(:request_expires_at, nil) }.to raise_error(ActiveRecord::StatementInvalid, /appointments_pending_expires/)
  end

  describe "double booking" do
    before { appointment.save! }

    it "rejects an active appointment overlapping another one of the professional" do
      overlapping = appointment(tomorrow_ten + 30.minutes)

      expect(overlapping).not_to be_valid
      expect(overlapping.errors).to be_of_kind(:base, :overlap)
    end

    it "counts the break" do
      expect(appointment(tomorrow_ten + 50.minutes)).not_to be_valid
      expect(appointment(tomorrow_ten + 55.minutes)).to be_valid
    end

    it "is checked in the database, which reports it as the same error" do
      overlapping = appointment(tomorrow_ten + 30.minutes)

      expect(overlapping.save(validate: false)).to be(false)
      expect(overlapping.errors).to be_of_kind(:base, :overlap)
    end

    it "ignores appointments that no longer hold their time" do
      Appointment.update_all(status: "cancelled")

      expect(appointment).to be_valid
      expect(appointment.save(validate: false)).to be(true)
    end

    it "allows inactive appointments to overlap" do
      expect(appointment(status: :cancelled)).to be_valid
    end

    it "allows the same time with another professional" do
      expect(appointment(professional: create(:professional, services: [ service ]))).to be_valid
    end
  end

  describe ".active" do
    it "includes pending and confirmed appointments" do
      pending = appointment.tap(&:save!)
      confirmed = appointment(tomorrow_ten + 1.hour, status: :confirmed).tap(&:save!)
      appointment(tomorrow_ten + 2.hours, status: :cancelled).save!

      expect(described_class.active).to contain_exactly(pending, confirmed)
    end
  end

  describe "management token" do
    let(:created) { appointment.tap(&:save!) }

    it "finds the appointment" do
      token = created.generate_token_for(:management)

      expect(described_class.find_by_token_for(:management, token)).to eq(created)
    end

    it "stays valid when the appointment moves or changes status" do
      token = created.generate_token_for(:management)
      created.update!(starts_at: tomorrow_ten + 2.hours, status: :confirmed)

      expect(described_class.find_by_token_for(:management, token)).to eq(created)
    end

    it "doesn't find appointments of another business" do
      token = created.generate_token_for(:management)

      with_business(create(:business)) do
        expect(described_class.find_by_token_for(:management, token)).to be_nil
      end
    end

    it "rejects tampered tokens" do
      expect(described_class.find_by_token_for(:management, "nope")).to be_nil
    end
  end

  it "belongs to a service, professional and customer of the same business in the database" do
    other = create(:business)
    other_customer = with_business(other) { create(:customer) }
    created = appointment.tap(&:save!)

    expect { created.update_column(:customer_id, other_customer.id) }.to raise_error(ActiveRecord::InvalidForeignKey)
  end
end
