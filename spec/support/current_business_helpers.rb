module CurrentBusinessHelpers
  # Runs the block with the given business as the current tenant.
  def with_business(business, &block)
    Current.set(business: business, &block)
  end
end

RSpec.configure do |config|
  config.include CurrentBusinessHelpers
end
