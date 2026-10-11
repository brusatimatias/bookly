# Public landing page of a business.
class BusinessesController < ApplicationController
  include SetCurrentBusiness

  def show
    @business = Current.business
  end
end
