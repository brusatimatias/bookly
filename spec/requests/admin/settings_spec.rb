require "rails_helper"

RSpec.describe "Admin settings", type: :request do
  let(:business) { create(:business, slot_interval_minutes: 30) }

  def sign_in_with_role(role)
    user = create(:user)
    create(:membership, business: business, user: user, role: role)
    sign_in_as(user)
  end

  describe "as the owner" do
    before { sign_in_with_role(:owner) }

    it "shows the booking settings with what each one changes" do
      get edit_admin_settings_path(business)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Configuración de reservas", "Intervalo de inicio", "Aviso mínimo", 'value="30"')
    end

    it "updates them" do
      patch admin_settings_path(business), params: { business: {
        slot_interval_minutes: 15, buffer_minutes: 5, min_booking_notice_hours: 1,
        booking_horizon_days: 30, request_expiration_hours: 12, cancellation_window_hours: 48
      } }

      expect(response).to redirect_to(edit_admin_settings_path(business))
      expect(flash[:notice]).to eq("Guardamos la configuración de reservas.")
      expect(business.reload).to have_attributes(slot_interval_minutes: 15, buffer_minutes: 5, min_booking_notice_hours: 1,
        booking_horizon_days: 30, request_expiration_hours: 12, cancellation_window_hours: 48)
    end

    it "shows the errors of invalid values" do
      patch admin_settings_path(business), params: { business: { slot_interval_minutes: 0, booking_horizon_days: 1000 } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("debe ser mayor que 0", "debe ser menor que o igual a 365")
      expect(business.reload.slot_interval_minutes).to eq(30)
    end

    it "only changes the booking settings" do
      patch admin_settings_path(business), params: { business: { slot_interval_minutes: 15, name: "Otro", slug: "otro" } }

      expect(business.reload).to have_attributes(slot_interval_minutes: 15, slug: business.slug)
      expect(business.name).not_to eq("Otro")
    end
  end

  it "is only for the owner" do
    sign_in_with_role(:admin)

    get edit_admin_settings_path(business)
    expect(response).to redirect_to(admin_root_path(business))

    patch admin_settings_path(business), params: { business: { slot_interval_minutes: 15 } }
    expect(business.reload.slot_interval_minutes).to eq(30)
  end
end
