# A business's public pages are served from its subdomain: request specs for
# them switch to its host first (use_business_host(business)), and stay on the
# app's own domain (www.example.com) otherwise.
module BusinessHostHelpers
  def business_host(business)
    "#{business.slug}.#{Rails.configuration.x.app_host}"
  end

  def use_business_host(business)
    host! business_host(business)
  end
end

RSpec.configure do |config|
  config.include BusinessHostHelpers, type: :request
end
