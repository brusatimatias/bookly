# The business's own details: name, contact, address, time zone, language and
# currency. Only the owner changes them. The web address (slug) stays: customers
# already have links to it.
class Admin::BusinessesController < Admin::BaseController
  DETAILS = %i[name contact_email contact_phone address time_zone locale currency].freeze

  before_action :require_owner

  def edit
    @business = Current.business
  end

  def update
    # A copy, so the layout keeps showing the saved name if this one is invalid.
    @business = Business.find(Current.business.id)

    if @business.update(params.expect(business: DETAILS))
      # In the language the panel is shown in from now on.
      redirect_to edit_admin_business_path, notice: I18n.with_locale(@business.locale) { t(".updated") }
    else
      render :edit, status: :unprocessable_entity
    end
  end
end
