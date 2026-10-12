require "rails_helper"

RSpec.describe Admin::BaseController, type: :controller do
  controller(described_class) do
    before_action :require_owner, only: :owners
    before_action :require_manager, only: :managers

    def owners
      render plain: "owners"
    end

    def managers
      render plain: "managers"
    end
  end

  let(:business) { create(:business) }

  before do
    routes.draw do
      scope ":business_slug" do
        get "admin", to: "admin/base#show", as: :admin_root
        get "admin/owners", to: "admin/base#owners"
        get "admin/managers", to: "admin/base#managers"
      end
    end
  end

  def sign_in_with_role(role)
    user = create(:user)
    create(:membership, business: business, user: user, role: role)
    cookies.signed[:session_id] = user.sessions.create!.id
  end

  describe "require_owner" do
    it "lets the owner in" do
      sign_in_with_role(:owner)

      get :owners, params: { business_slug: business.slug }

      expect(response.body).to eq("owners")
    end

    it "sends admins and professionals back to the panel home" do
      %i[admin professional].each do |role|
        sign_in_with_role(role)

        get :owners, params: { business_slug: business.slug }

        expect(response).to redirect_to("/#{business.slug}/admin")
        expect(flash[:alert]).to eq("No tenés permiso para acceder a esa sección.")
      end
    end
  end

  describe "require_manager" do
    it "lets owners and admins in" do
      %i[owner admin].each do |role|
        sign_in_with_role(role)

        get :managers, params: { business_slug: business.slug }

        expect(response.body).to eq("managers")
      end
    end

    it "sends professionals back to the panel home" do
      sign_in_with_role(:professional)

      get :managers, params: { business_slug: business.slug }

      expect(response).to redirect_to("/#{business.slug}/admin")
    end
  end
end
