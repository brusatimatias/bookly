require "rails_helper"

RSpec.describe BusinessesHelper, type: :helper do
  describe "#time_zone_options" do
    it "lists each identifier once, labeled with its offset and Rails name" do
      options = helper.time_zone_options

      expect(options).to include([ "(GMT-03:00) Buenos Aires", "America/Argentina/Buenos_Aires" ])
      expect(options.map(&:last)).to eq(options.map(&:last).uniq)
      expect(options.map(&:last)).to all(satisfy { |identifier| TZInfo::Timezone.all_identifiers.include?(identifier) })
    end

    it "keeps a selected identifier without a Rails name" do
      expect(helper.time_zone_options("America/Argentina/Cordoba")).to include([ "America/Argentina/Cordoba", "America/Argentina/Cordoba" ])
    end
  end

  describe "#currency_options" do
    it "names every currency in the current language" do
      expect(helper.currency_options).to include([ "ARS — Peso argentino", "ARS" ])
      I18n.with_locale(:en) { expect(helper.currency_options).to include([ "USD — US dollar", "USD" ]) }
    end
  end
end
