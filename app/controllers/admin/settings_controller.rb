# The business's booking rules, which shape the times customers can book, and
# its reminders. Only the owner changes them.
class Admin::SettingsController < Admin::BaseController
  BOOKING_SETTINGS = %i[slot_interval_minutes buffer_minutes min_booking_notice_hours booking_horizon_days
                        request_expiration_hours cancellation_window_hours reminder_hours_before].freeze

  before_action :require_owner

  def edit
    @business = Current.business
  end

  def update
    @business = Current.business

    if @business.update(params.expect(business: BOOKING_SETTINGS))
      redirect_to edit_admin_settings_path, notice: t(".updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end
end
