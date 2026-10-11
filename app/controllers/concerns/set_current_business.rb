# Resolves the business from the /:business_slug path segment and runs the
# request in its context: Current.business, its locale and its time zone.
#
# Unknown slugs respond 404. Suspended businesses render an "unavailable" page.
module SetCurrentBusiness
  extend ActiveSupport::Concern

  included do
    around_action :scope_to_current_business
  end

  private
    def scope_to_current_business(&action)
      Current.business = Business.find_by!(slug: params[:business_slug])

      I18n.with_locale(Current.business.locale) do
        Time.use_zone(Current.business.time_zone) do
          if Current.business.suspended?
            render "businesses/unavailable", status: :service_unavailable
          else
            action.call
          end
        end
      end
    end
end
