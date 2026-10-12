require "rails_helper"

RSpec.describe BusinessScoped do
  # Exercised through a throwaway table and model that only live during this
  # spec, so the concern is tested on its own.
  before(:all) do
    ActiveRecord::Base.connection.create_table :scoped_widgets, force: true do |t|
      t.references :business, null: false, foreign_key: true
      t.string :name
    end
  end

  after(:all) do
    ActiveRecord::Base.connection.drop_table :scoped_widgets, if_exists: true
  end

  let(:widget_class) do
    klass = Class.new(ApplicationRecord) { self.table_name = "scoped_widgets" }
    stub_const("ScopedWidget", klass)
    klass.include(BusinessScoped)
    klass
  end

  let(:business) { create(:business) }
  let(:other_business) { create(:business) }

  describe "without a current business" do
    it "raises on queries" do
      expect { widget_class.count }.to raise_error(Current::MissingBusiness)
    end

    it "raises on lookups by id" do
      widget = with_business(business) { widget_class.create!(name: "Mine") }

      expect { widget_class.find(widget.id) }.to raise_error(Current::MissingBusiness)
    end

    it "raises when building records" do
      expect { widget_class.new(name: "Orphan") }.to raise_error(Current::MissingBusiness)
    end
  end

  describe "with a current business" do
    it "assigns the current business to new records" do
      widget = with_business(business) { widget_class.create!(name: "Mine") }

      expect(widget.business).to eq(business)
    end

    it "only returns records of the current business" do
      mine = with_business(business) { widget_class.create!(name: "Mine") }
      theirs = with_business(other_business) { widget_class.create!(name: "Theirs") }

      with_business(business) do
        expect(widget_class.all).to contain_exactly(mine)
        expect { widget_class.find(theirs.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    it "does not update records of another business" do
      theirs = with_business(other_business) { widget_class.create!(name: "Theirs") }

      with_business(business) do
        expect(widget_class.where(id: theirs.id).update_all(name: "Hacked")).to eq(0)
      end
      expect(theirs.reload.name).to eq("Theirs")
    end

    it "does not allow moving a record to another business" do
      widget = with_business(business) { widget_class.create!(name: "Mine") }

      with_business(business) do
        expect { widget.update!(business: other_business) }.to raise_error(ActiveRecord::ReadonlyAttributeError)
      end
    end
  end

  describe ".across_businesses" do
    it "returns records of every business" do
      mine = with_business(business) { widget_class.create!(name: "Mine") }
      theirs = with_business(other_business) { widget_class.create!(name: "Theirs") }

      described_class.across_businesses do
        expect(widget_class.all).to contain_exactly(mine, theirs)
      end
    end

    it "fails closed again after the block" do
      described_class.across_businesses { widget_class.count }

      expect { widget_class.count }.to raise_error(Current::MissingBusiness)
    end
  end
end
