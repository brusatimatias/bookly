# Public landing page of a business.
class BusinessesController < ApplicationController
  include SetCurrentBusiness
  allow_unauthenticated_access

  def show
    @business = Current.business
    @services = @business.services.bookable.with_rich_text_description.order(Service.arel_table[:name].lower)
    @professionals = @business.professionals.bookable.includes(:services, photo_attachment: :blob).order(Professional.arel_table[:name].lower)
  end
end
