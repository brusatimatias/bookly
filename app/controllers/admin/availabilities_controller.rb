# A week of free start times, as customers will see them: owners and admins
# for any service and professional (or any professional), professionals for
# their own profile.
class Admin::AvailabilitiesController < Admin::BaseController
  include AvailabilityWeek

  def show
    @own_profile = Current.membership.professional_profile unless Current.membership.manager?
    @services = services.to_a
    @service = @services.find { |service| service.id == params[:service_id].to_i } || @services.first
    return unless @service

    @professionals = professionals_for(@service)
    @professional = @own_profile || @professionals.find { |professional| professional.id == params[:professional_id].to_i }
    load_availability_week(Availability.new(@service, professional: @professional))
  end

  private
    # Bookable services; a professional's own, for professionals.
    def services
      scope = Current.membership.manager? ? Current.business.services : (@own_profile&.services || Service.none)
      scope.merge(Service.bookable).order(Service.arel_table[:name].lower)
    end

    def professionals_for(service)
      return [] unless Current.membership.manager?

      service.professionals.merge(Professional.bookable).order(Professional.arel_table[:name].lower).to_a
    end
end
