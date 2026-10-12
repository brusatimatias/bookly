require "rails_helper"

RSpec.describe IconsHelper, type: :helper do
  describe "#icon" do
    it "renders an inline SVG hidden from assistive technology" do
      svg = helper.icon("users")

      expect(svg).to include("<svg", 'aria-hidden="true"', IconsHelper::ICONS["users"])
      expect(svg).to include('class="size-5 shrink-0"')
    end

    it "appends extra classes" do
      expect(helper.icon("users", class: "text-gray-400")).to include('class="size-5 shrink-0 text-gray-400"')
    end

    it "raises for unknown icons" do
      expect { helper.icon("unknown") }.to raise_error(KeyError)
    end
  end

  describe "#initials" do
    it "takes the first letter of up to two words" do
      expect(helper.initials("Lucía Fernández López")).to eq("LF")
      expect(helper.initials("sam")).to eq("S")
    end
  end
end
