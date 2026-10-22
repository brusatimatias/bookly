require "rails_helper"

RSpec.describe "Old public paths", type: :request do
  let!(:business) { create(:business, slug: "barberia-centro") }

  it "moves the business's page, the booking and the appointment's pages to its subdomain, keeping the query" do
    {
      "/barberia-centro" => "http://barberia-centro.example.com/",
      "/barberia-centro/book?service_id=7&professional_id=any" => "http://barberia-centro.example.com/book?service_id=7&professional_id=any",
      "/barberia-centro/appointments/abc" => "http://barberia-centro.example.com/appointments/abc",
      "/barberia-centro/appointments/abc.ics" => "http://barberia-centro.example.com/appointments/abc.ics",
      "/barberia-centro/appointments/abc/cancellation/new" => "http://barberia-centro.example.com/appointments/abc/cancellation/new",
      "/barberia-centro/appointments/abc/reschedule/new?week=2026-10-26" => "http://barberia-centro.example.com/appointments/abc/reschedule/new?week=2026-10-26"
    }.each do |old_path, new_url|
      get old_path

      expect(response).to have_http_status(:moved_permanently)
      expect(response.location).to eq(new_url)
    end
  end

  it "works from the domain without www too" do
    host! "example.com"

    get "/barberia-centro/book"

    expect(response.location).to eq("http://barberia-centro.example.com/book")
  end

  it "leaves the panel and the app's own paths alone" do
    get "/barberia-centro/admin"
    expect(response).to redirect_to(new_session_path)

    get "/session"
    expect(response).to have_http_status(:not_found)
  end
end
