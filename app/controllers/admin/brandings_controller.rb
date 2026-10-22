# The business's brand: its logo and color, on its public pages and the
# emails customers get. Only the owner changes them.
class Admin::BrandingsController < Admin::BaseController
  before_action :require_owner

  def edit
    @business = Current.business
  end

  def update
    # A copy, so the preview keeps showing the saved logo if this one is invalid.
    @business = Business.find(Current.business.id)
    brand = params.expect(business: %i[brand_color logo remove_logo])
    @business.assign_attributes(brand.slice(:brand_color, :logo))
    @business.logo = nil if brand[:remove_logo] == "1" && brand[:logo].blank?

    if @business.save
      redirect_to edit_admin_branding_path, notice: t(".updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end
end
