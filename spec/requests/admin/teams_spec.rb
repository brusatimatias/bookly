require "rails_helper"

RSpec.describe "Admin team", type: :request do
  let(:business) { create(:business) }
  let!(:owner) { create(:membership, :owner, business: business, user: create(:user, name: "Lucía")).user }

  before { create(:invitation, business: business, email: "ana@example.com", invited_by: owner) }

  def sign_in_with_role(role)
    user = create(:user)
    create(:membership, business: business, user: user, role: role)
    sign_in_as(user)
  end

  it "shows members and pending invitations, with actions, to the owner" do
    sign_in_as(owner)

    get admin_team_path(business)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Lucía", "Dueño", "ana@example.com", "Invitar", "Reenviar", "Revocar")
  end

  it "lets admins see the team without managing invitations" do
    sign_in_with_role(:admin)

    get admin_team_path(business)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("ana@example.com")
    expect(response.body).not_to include("Reenviar", "Revocar", new_admin_invitation_path(business))
  end

  it "is not available to professionals" do
    sign_in_with_role(:professional)

    get admin_team_path(business)

    expect(response).to redirect_to(admin_root_path(business))
  end

  it "does not list accepted invitations" do
    create(:invitation, business: business, email: "done@example.com", invited_by: owner, accepted_at: Time.current)
    sign_in_as(owner)

    get admin_team_path(business)

    expect(response.body).not_to include("done@example.com")
  end
end
