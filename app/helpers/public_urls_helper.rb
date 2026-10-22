# A business's public pages (its page, the booking and the customer's
# appointment links) live on its subdomain. Links to them from another host
# (the panel, the platform, emails) pass these options to the route helpers:
# business_url(public_url_options(business)). The panel's business_slug
# default is cleared so it isn't added as a query parameter.
module PublicUrlsHelper
  def public_url_options(business)
    { subdomain: business.slug, business_slug: nil }
  end
end
