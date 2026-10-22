# Resolves the business from the host's subdomain (public pages) or the
# /:business_slug path segment (the panel) and runs the request in its
# context: Current.business, its locale and its time zone.
#
# Unknown slugs respond 404. Suspended businesses render an "unavailable" page.
module SetCurrentBusiness
  extend ActiveSupport::Concern

  included do
    around_action :scope_to_current_business
  end

  private
    def scope_to_current_business(&action)
      Current.business = Business.find_by!(slug: params[:business_slug] || request.subdomain)

      I18n.with_locale(Current.business.locale) do
        Time.use_zone(Current.business.time_zone) do
          if Current.business.suspended?
            render "businesses/unavailable", status: :service_unavailable, layout: "application"
          else
            action.call
          end
        end
      end
    end
end
