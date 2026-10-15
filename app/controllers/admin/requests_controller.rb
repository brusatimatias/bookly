# Requests waiting for an answer, the ones expiring first on top. Professionals
# see their own; owners and admins every one.
class Admin::RequestsController < Admin::BaseController
  def index
    @requests = Current.membership.visible_appointments.awaiting_answer
      .includes(:service, :customer, professional: { photo_attachment: :blob })
      .order(:request_expires_at, :starts_at)
  end
end
