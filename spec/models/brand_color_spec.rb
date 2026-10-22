require "rails_helper"

RSpec.describe BrandColor do
  it "measures the contrast against white as WCAG does" do
    expect(described_class.new("#ffffff").contrast_with_white).to be_within(0.01).of(1)
    expect(described_class.new("#000000").contrast_with_white).to be_within(0.01).of(21)
    expect(described_class.new("#767676").contrast_with_white).to be_within(0.01).of(4.54)
  end

  it "takes white text on colors with a contrast of 4.5 or more" do
    expect(described_class.new("#767676")).to be_readable_with_white_text
    expect(described_class.new("#777777")).not_to be_readable_with_white_text
  end

  it "defaults to a readable color" do
    expect(described_class.new(BrandColor::DEFAULT)).to be_readable_with_white_text
  end
end
