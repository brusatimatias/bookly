require "rails_helper"

RSpec.describe "Admin schedules", type: :request do
  let(:business) { create(:business, time_zone: "America/Argentina/Buenos_Aires") }
  let(:professional) { with_business(business) { create(:professional, name: "Sofía Torres") } }

  def member(role)
    create(:membership, business: business, role: role).user
  end

  def saved_ranges
    with_business(business) do
      professional.working_hours.ordered.map { |range| [ range.day_of_week, range.start_time.strftime("%H:%M"), range.end_time.strftime("%H:%M") ] }
    end
  end

  def ranges_params(*ranges)
    { schedule: { ranges: ranges.map { |day, start_time, end_time| { day_of_week: day, start_time: start_time, end_time: end_time } } } }
  end

  describe "as a manager" do
    before { sign_in_as(member(:admin)) }

    it "shows the week Monday first, with the ranges in the business's local time" do
      with_business(business) { create(:working_hour, professional: professional, day_of_week: 1, start_time: "14:00", end_time: "20:00") }

      get edit_admin_professional_schedule_path(business, professional)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Horario de Sofía Torres", "en hora de Buenos Aires", 'value="14:00"', 'value="20:00"', "No trabaja")
      expect(response.body.index("Lunes")).to be < response.body.index("Domingo")
    end

    it "saves the week and goes back to the professionals" do
      patch admin_professional_schedule_path(business, professional),
        params: ranges_params([ 1, "09:00", "13:00" ], [ 1, "14:00", "18:00" ], [ 6, "10:00", "14:00" ])

      expect(response).to redirect_to(admin_professionals_path(business))
      expect(flash[:notice]).to eq("Guardamos el horario de Sofía Torres.")
      expect(saved_ranges).to eq([ [ 1, "09:00", "13:00" ], [ 1, "14:00", "18:00" ], [ 6, "10:00", "14:00" ] ])
    end

    it "clears the week when every range is removed" do
      with_business(business) { create(:working_hour, professional: professional) }

      patch admin_professional_schedule_path(business, professional)

      expect(response).to redirect_to(admin_professionals_path(business))
      expect(saved_ranges).to be_empty
    end

    it "shows the errors next to each range, keeping what was typed" do
      patch admin_professional_schedule_path(business, professional),
        params: ranges_params([ 2, "09:00", "13:00" ], [ 2, "12:00", "15:00" ])

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Revisá las franjas marcadas.", "La franja se superpone con otra del mismo día", 'value="12:00"')
      expect(saved_ranges).to be_empty
    end

    it "cannot edit professionals of another business" do
      other = with_business(create(:business)) { create(:professional) }

      get edit_admin_professional_schedule_path(business, other)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "as a professional" do
    it "cannot see or change the hours" do
      user = member(:professional)
      with_business(business) { professional.update!(user: user) }
      sign_in_as(user)

      get edit_admin_professional_schedule_path(business, professional)
      expect(response).to redirect_to(admin_root_path(business))

      patch admin_professional_schedule_path(business, professional), params: ranges_params([ 1, "09:00", "13:00" ])
      expect(saved_ranges).to be_empty
    end
  end
end
