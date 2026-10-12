require "rails_helper"

RSpec.describe "Admin dashboard", type: :request do
  let(:business) { create(:business, name: "Barbería Centro") }
  let(:user) { create(:user, name: "Lucía") }

  it "asks to sign in and then returns to the panel" do
    create(:membership, :owner, business: business, user: user)

    get admin_root_path(business)
    expect(response).to redirect_to(new_session_path)

    sign_in_as(user)
    expect(response).to redirect_to(admin_root_url(business))
  end

  it "shows the panel to members, in the business locale" do
    business.update!(locale: "en")
    create(:membership, :admin, business: business, user: user)
    sign_in_as(user)

    get admin_root_path(business)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('lang="en"', "Barbería Centro", "Hi, Lucía", "Admin")
  end

  it "responds not found to users who are not members" do
    create(:membership, :owner, business: create(:business), user: user)
    sign_in_as(user)

    get admin_root_path(business)

    expect(response).to have_http_status(:not_found)
  end

  it "responds not found for an unknown business" do
    sign_in_as(user)

    get admin_root_path(business_slug: "unknown")

    expect(response).to have_http_status(:not_found)
  end

  it "shows the unavailable page when the business is suspended" do
    create(:membership, :owner, business: business, user: user)
    business.suspend!
    sign_in_as(user)

    get admin_root_path(business)

    expect(response).to have_http_status(:service_unavailable)
  end
end
