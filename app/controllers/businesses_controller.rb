# Public landing page of a business.
class BusinessesController < ApplicationController
  include SetCurrentBusiness
  allow_unauthenticated_access

  def show
    @business = Current.business
  end
end
