require "rails_helper"

RSpec.describe BusinessSetup do
  let(:business) { create(:business) }

  around { |example| with_business(business) { example.run } }

  subject(:setup) { described_class.new }

  it "starts with every task left, at the business's details" do
    expect(setup).not_to be_service
    expect(setup).not_to be_professional
    expect(setup).not_to be_hours
    expect(setup).not_to be_complete
    expect(setup.first_step).to eq("details")
    expect(setup.next_step).to eq("service")
  end

  it "needs an active service" do
    create(:service, :inactive)
    expect(described_class.new).not_to be_service

    create(:service)
    expect(described_class.new).to be_service
    expect(described_class.new.first_step).to eq("professional")
  end

  it "needs an active professional offering an active service" do
    service = create(:service)
    create(:professional)
    create(:professional, :inactive, services: [ service ])
    create(:professional, services: [ create(:service, :inactive) ])
    expect(described_class.new).not_to be_professional

    create(:professional, services: [ service ])
    expect(described_class.new).to be_professional
    expect(described_class.new.next_step).to eq("hours")
  end

  it "is complete once that professional has weekly hours" do
    create(:professional, :with_hours, services: [ create(:service) ])

    expect(setup).to be_complete
    expect(setup.next_step).to eq("done")
    expect(setup.first_step).to eq("done")
  end

  it "only reads the current business" do
    with_business(create(:business)) { create(:professional, :with_hours, services: [ create(:service) ]) }

    expect(setup).not_to be_service
  end
end
