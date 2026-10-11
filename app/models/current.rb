class Current < ActiveSupport::CurrentAttributes
  # Raised when tenant data is accessed without a current business. See BusinessScoped.
  class MissingBusiness < StandardError
    def initialize(message = "No current business. Wrap the code in Current.set(business: business) { ... }")
      super
    end
  end

  attribute :business
  attribute :across_businesses

  def business!
    business || raise(MissingBusiness)
  end
end
