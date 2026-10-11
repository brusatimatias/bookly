# Isolates a model's rows by business (multi-tenancy).
#
# Every query is filtered by Current.business, and new records get it assigned
# automatically. With no current business it fails closed: any query or
# instantiation raises Current::MissingBusiness instead of touching every tenant.
#
#   Current.set(business: business) { Service.all }  # only this business's services
#   Service.all                                      # raises Current::MissingBusiness
#
# Code that legitimately spans tenants (platform admin, maintenance tasks) must
# opt out explicitly:
#
#   BusinessScoped.across_businesses { Service.count }
module BusinessScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :business

    attr_readonly :business_id

    default_scope { where(business: Current.business!) unless Current.across_businesses }
  end

  def self.across_businesses(&block)
    Current.set(across_businesses: true, &block)
  end
end
