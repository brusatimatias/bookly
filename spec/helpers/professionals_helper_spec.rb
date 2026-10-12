require "rails_helper"

RSpec.describe ProfessionalsHelper, type: :helper do
  let(:business) { create(:business) }

  around { |example| with_business(business) { example.run } }

  it "shows the initials when there is no photo" do
    avatar = helper.professional_avatar(build(:professional, name: "Sofía Torres"))

    expect(avatar).to include("ST", "size-10")
    expect(avatar).not_to include("<img")
  end

  it "shows the photo when there is one" do
    professional = create(:professional, name: "Sofía Torres")
    professional.photo.attach(io: file_fixture("photo.png").open, filename: "photo.png", content_type: "image/png")

    avatar = helper.professional_avatar(professional, size: "size-16")

    expect(avatar).to include("<img", 'alt="Sofía Torres"', "/rails/active_storage/blobs/", "size-16", "object-cover")
  end

  it "falls back to the initials while an upload isn't saved" do
    professional = build(:professional, name: "Sofía Torres")
    professional.photo.attach(io: file_fixture("photo.png").open, filename: "photo.png", content_type: "image/png")

    expect(helper.professional_avatar(professional)).not_to include("<img")
  end
end
