# Base for emails about one business's records. Parameterized with the business
# (`.with(business:, ...)`), they run inside its tenant context, language and
# time zone, so they can load business-scoped records in the job that delivers
# them: pass ids, not records, which would be loaded before the tenant is set.
# Sent in the business's name; replies go to its contact email.
class BusinessMailer < ApplicationMailer
  helper FormattingHelper

  default from: -> { email_address_with_name(Rails.configuration.x.mail_from, business.name) },
          reply_to: -> { business.contact_email.presence }

  around_action :within_business

  private
    def business
      params.fetch(:business)
    end

    def within_business(&action)
      @business = business
      Current.set(business: business) do
        I18n.with_locale(business.locale) { Time.use_zone(business.time_zone, &action) }
      end
    end
end
