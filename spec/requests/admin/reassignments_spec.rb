require "rails_helper"

RSpec.describe "Admin reassignments", type: :request do
  let(:business) { create(:business, time_zone: "America/Argentina/Buenos_Aires") }
  let(:zone) { Time.find_zone!(business.time_zone) }
  let(:service) { in_business { create(:service, duration_minutes: 30, buffer_minutes: 0) } }
  let(:martin) { working_tuesdays("Martín") }
  let(:sofia) { working_tuesdays("Sofía") }
  # Tuesday 10:00, the day after "now".
  let(:appointment) { in_business { create(:appointment, service: service, professional: martin, starts_at: zone.local(2026, 10, 20, 10)) } }
  let(:manager) { create(:membership, :admin, business: business).user }

  around { |example| travel_to(Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 10, 19, 12)) { example.run } }

  def in_business(&block)
    with_business(business, &block)
  end

  def working_tuesdays(name)
    in_business do
      create(:professional, name: name, services: [ service ]).tap do |professional|
        create(:working_hour, professional: professional, day_of_week: 2, start_time: "09:00", end_time: "13:00")
      end
    end
  end

  it "lists the other professionals offering the service" do
    sofia
    in_business { create(:professional, name: "Pablo") }
    sign_in_as(manager)

    get new_admin_appointment_reassignment_path(business, appointment)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Reasignar turno", ">Sofía</option>")
    expect(response.body).not_to include(">Martín</option>", ">Pablo</option>")
  end

  it "reassigns the appointment" do
    sign_in_as(manager)

    post admin_appointment_reassignment_path(business, appointment), params: { reassignment: { professional_id: sofia.id } }

    expect(response).to redirect_to(admin_appointment_url(business, appointment))
    expect(flash[:notice]).to eq("Reasignamos el turno a Sofía.")
    in_business { expect(appointment.reload.professional).to eq(sofia) }
  end

  it "explains why a professional isn't free, keeping the appointment" do
    in_business { create(:time_block, professional: sofia, starts_at: zone.local(2026, 10, 20, 9), ends_at: zone.local(2026, 10, 20, 11)) }
    sign_in_as(manager)

    post admin_appointment_reassignment_path(business, appointment), params: { reassignment: { professional_id: sofia.id } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Profesional tiene un bloqueo en ese horario")
    in_business { expect(appointment.reload.professional).to eq(martin) }
  end

  it "requires one of the listed professionals" do
    other_business_professional = with_business(create(:business)) { create(:professional) }
    sign_in_as(manager)

    post admin_appointment_reassignment_path(business, appointment), params: { reassignment: { professional_id: other_business_professional.id } }

    expect(response).to have_http_status(:unprocessable_entity)
    in_business { expect(appointment.reload.professional).to eq(martin) }
  end

  it "is for owners and admins only, not for the professional of the appointment" do
    professional = create(:membership, business: business).user
    in_business { martin.update!(user: professional) }
    sign_in_as(professional)

    get new_admin_appointment_reassignment_path(business, appointment)
    expect(response).to redirect_to(admin_root_url(business))

    post admin_appointment_reassignment_path(business, appointment), params: { reassignment: { professional_id: sofia.id } }
    in_business { expect(appointment.reload.professional).to eq(martin) }
  end
end
