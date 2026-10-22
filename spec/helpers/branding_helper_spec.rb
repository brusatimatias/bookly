require "rails_helper"

RSpec.describe BrandingHelper, type: :helper do
  describe "#brand_style_tag" do
    it "replaces the brand scale with the business's color and shades of it" do
      style = helper.brand_style_tag(build(:business, brand_color: "#0f766e"))

      expect(style).to start_with("<style>").and include("--color-brand-600: #0f766e;",
        "--color-brand-50: color-mix(in oklab, #0f766e, white 92%);", "--color-brand-900: color-mix(in oklab, #0f766e, black 46%);")
    end

    it "keeps Bookly's without a color or a business" do
      expect(helper.brand_style_tag(build(:business))).to be_nil
      expect(helper.brand_style_tag(nil)).to be_nil
    end
  end

  describe "#branded_business" do
    it "is the current business while it's active" do
      business = create(:business)

      Current.set(business: business) { expect(helper.branded_business).to eq(business) }
      business.suspend!
      Current.set(business: business) { expect(helper.branded_business).to be_nil }
      expect(helper.branded_business).to be_nil
    end
  end
end
