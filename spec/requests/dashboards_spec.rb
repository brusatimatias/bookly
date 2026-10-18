require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user) }

  it "is where users land after signing in" do
    sign_in_as(user)

    expect(response).to redirect_to(dashboard_url)
  end

  it "requires signing in" do
    get dashboard_path

    expect(response).to redirect_to(new_session_path)
  end

  it "goes straight to the panel of a user's only business" do
    business = create(:business)
    create(:membership, :owner, business: business, user: user)
    sign_in_as(user)

    get dashboard_path

    expect(response).to redirect_to(admin_root_path(business))
  end

  it "lists the businesses of a user with several, with their role" do
    create(:membership, :owner, business: create(:business, name: "Barbería Centro"), user: user)
    create(:membership, business: create(:business, name: "Downtown Studio"), user: user)
    sign_in_as(user)

    get dashboard_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Barbería Centro", "Dueño", "Downtown Studio", "Profesional")
  end

  it "takes platform admins without a business to the platform panel" do
    user.update!(platform_admin: true)
    sign_in_as(user)

    get dashboard_path

    expect(response).to redirect_to(platform_root_path)
  end

  it "explains when the user has no businesses" do
    sign_in_as(user)

    get dashboard_path

    expect(response.body).to include("Todavía no formás parte de ningún negocio.")
  end
end
