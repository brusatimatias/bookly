require "rails_helper"

RSpec.describe FormattingHelper, type: :helper do
  describe "#format_price" do
    let(:business) { create(:business, currency: "ARS") }

    around { |example| with_business(business) { example.run } }

    it "formats whole amounts without decimals, in the Argentine style" do
      expect(helper.format_price(1_200_000)).to eq("$ 12.000")
    end

    it "shows cents when there are any" do
      expect(helper.format_price(1_250)).to eq("$ 12,50")
    end

    it "shows free services as zero" do
      expect(helper.format_price(0)).to eq("$ 0")
    end

    it "follows the locale" do
      I18n.with_locale(:en) do
        expect(helper.format_price(1_200_050)).to eq("$12,000.50")
      end
    end

    it "uses the code of currencies without a known symbol" do
      expect(helper.format_price(150_000, currency: "CLP")).to eq("CLP 1.500")
      I18n.with_locale(:en) { expect(helper.format_price(150_000, currency: "CLP")).to eq("CLP 1,500") }
    end
  end

  describe "#format_duration" do
    it "shows minutes" do
      expect(helper.format_duration(45)).to eq("45 min")
    end

    it "shows whole hours" do
      expect(helper.format_duration(120)).to eq("2 h")
    end

    it "shows hours and minutes" do
      expect(helper.format_duration(90)).to eq("1 h 30 min")
    end
  end

  describe "#time_zone_label" do
    it "uses the friendly Rails name when there is one" do
      expect(helper.time_zone_label("America/Argentina/Buenos_Aires")).to eq("Buenos Aires")
    end

    it "falls back to the identifier" do
      expect(helper.time_zone_label("America/Argentina/Cordoba")).to eq("America/Argentina/Cordoba")
    end

    it "defaults to the current business's time zone" do
      with_business(create(:business, time_zone: "America/New_York")) do
        expect(helper.time_zone_label).to eq("Eastern Time (US & Canada)")
      end
    end
  end

  describe "#format_period" do
    around { |example| Time.use_zone("America/Argentina/Buenos_Aires") { example.run } }

    it "shows the day once within a day" do
      expect(helper.format_period(Time.zone.local(2026, 10, 15, 16), Time.zone.local(2026, 10, 15, 19))).to eq("jue 15 oct, 16:00 – 19:00")
    end

    it "shows both days across days" do
      expect(helper.format_period(Time.zone.local(2026, 10, 15, 22), Time.zone.local(2026, 10, 16, 8))).to eq("jue 15 oct 22:00 – vie 16 oct 08:00")
    end
  end
end
