class Current < ActiveSupport::CurrentAttributes
  # Raised when tenant data is accessed without a current business. See BusinessScoped.
  class MissingBusiness < StandardError
    def initialize(message = "No current business. Wrap the code in Current.set(business: business) { ... }")
      super
    end
  end

  attribute :session
  attribute :business
  attribute :membership
  attribute :across_businesses

  delegate :user, to: :session, allow_nil: true

  def business!
    business || raise(MissingBusiness)
  end
end
