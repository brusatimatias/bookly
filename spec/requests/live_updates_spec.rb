require "rails_helper"

# Pages showing appointments subscribe to their business's stream and refresh
# themselves (morphing) when an appointment changes; pages with forms don't.
RSpec.describe "Live updates", type: :request do
  let(:business) { create(:business, time_zone: "America/Argentina/Buenos_Aires", min_booking_notice_hours: 0) }
  let(:zone) { Time.find_zone!(business.time_zone) }
  let(:service) { in_business { create(:service, duration_minutes: 30) } }
  let(:professional) do
    in_business do
      create(:professional, services: [ service ]).tap { |created| create(:working_hour, professional: created, day_of_week: 4, start_time: "09:00", end_time: "10:00") }
    end
  end
  let(:appointment) { in_business { create(:appointment, service: service, professional: professional, starts_at: zone.local(2026, 10, 15, 9)) } }

  # A Wednesday morning.
  around { |example| travel_to(Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 10, 14, 8)) { example.run } }

  def in_business(&block)
    with_business(business, &block)
  end

  def subscribed_to?(stream)
    response.body.include?(%(signed-stream-name="#{signed_turbo_stream_name(stream)}"))
  end

  def refreshes_by_morphing?
    response.body.include?('<meta name="turbo-refresh-method" content="morph">')
  end

  describe "in the panel" do
    before { sign_in_as(create(:membership, :owner, business: business).user) }

    it "subscribes the dashboard, requests, agenda and appointment page to the business's stream" do
      [ admin_root_path(business), admin_requests_path(business), admin_agenda_path(business), admin_appointment_path(business, appointment) ].each do |path|
        get path

        expect(subscribed_to?(Appointment.panel_stream(business))).to be(true), path
        expect(refreshes_by_morphing?).to be(true), path
      end
    end

    it "leaves forms out, so a refresh never wipes what someone types" do
      get new_admin_appointment_rejection_path(business, appointment)

      expect(response.body).not_to include("turbo-cable-stream-source")
    end

    it "never subscribes to another business's stream" do
      get admin_agenda_path(business)

      expect(subscribed_to?(Appointment.panel_stream(create(:business)))).to be(false)
    end
  end

  describe "on the public booking page" do
    it "subscribes the week of free times to the business's availability stream, not the panel's" do
      use_business_host(business)
      get new_booking_path(service_id: service.id, professional_id: professional.id)

      expect(response.body).to include("09:00")
      expect(subscribed_to?(Appointment.availability_stream(business))).to be(true)
      expect(subscribed_to?(Appointment.panel_stream(business))).to be(false)
      expect(refreshes_by_morphing?).to be(true)
    end

    it "subscribes the customer's appointment page to that appointment's stream only" do
      token = in_business { appointment.generate_token_for(:management) }
      other = in_business { create(:appointment, service: service, professional: professional, starts_at: appointment.starts_at + 1.hour) }

      use_business_host(business)
      get appointment_path(token)

      expect(subscribed_to?(appointment.customer_stream)).to be(true)
      expect(subscribed_to?(other.customer_stream)).to be(false)
      expect(subscribed_to?(Appointment.panel_stream(business))).to be(false)
      expect(refreshes_by_morphing?).to be(true)
    end

    it "leaves the cancellation and reschedule forms out" do
      token = in_business { appointment.generate_token_for(:management) }

      use_business_host(business)
      get new_appointment_cancellation_path(token)

      expect(response.body).not_to include("turbo-cable-stream-source")
    end

    it "leaves the other steps out" do
      use_business_host(business)
      get new_booking_path

      expect(response.body).not_to include("turbo-cable-stream-source")
    end
  end
end
