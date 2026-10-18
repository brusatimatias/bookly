require "rails_helper"

RSpec.describe SetCurrentBusiness, type: :controller do
  controller(ApplicationController) do
    include SetCurrentBusiness
    allow_unauthenticated_access

    def index
      render plain: [ Current.business.slug, I18n.locale, Time.zone.name ].join(" ")
    end
  end

  before do
    routes.draw { get ":business_slug/probe", to: "anonymous#index" }
  end

  it "sets the current business, locale and time zone from the slug" do
    create(:business, slug: "downtown", locale: "en", time_zone: "America/New_York")

    get :index, params: { business_slug: "downtown" }

    expect(response.body).to eq("downtown en America/New_York")
  end

  it "restores the default locale and time zone afterwards" do
    create(:business, slug: "downtown", locale: "en", time_zone: "America/New_York")

    get :index, params: { business_slug: "downtown" }

    expect(I18n.locale).to eq(:es)
    expect(Time.zone.name).to eq("UTC")
  end
end
