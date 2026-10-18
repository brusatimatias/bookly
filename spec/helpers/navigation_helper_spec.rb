require "rails_helper"

RSpec.describe NavigationHelper, type: :helper do
  describe "#admin_nav_link" do
    it "renders a link with its icon" do
      link = helper.admin_nav_link("Equipo", "/centro/admin/team", icon: "users")

      expect(link).to include('href="/centro/admin/team"', "Equipo", "<svg")
      expect(link).not_to include("aria-current")
    end

    it "marks the active link" do
      link = helper.admin_nav_link("Equipo", "/centro/admin/team", icon: "users", active: true)

      expect(link).to include('aria-current="page"', "bg-brand-50")
    end

    it "passes extra options to the link" do
      expect(helper.admin_nav_link("Web", "/centro", icon: "external-link", target: "_blank")).to include('target="_blank"')
    end
  end
end
