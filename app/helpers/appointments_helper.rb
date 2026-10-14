module AppointmentsHelper
  STATUS_BADGES = {
    "pending" => "badge-yellow", "confirmed" => "badge-green", "attended" => "badge-green",
    "rejected" => "badge-red", "cancelled" => "badge-red", "expired" => "badge-gray", "no_show" => "badge-gray"
  }.freeze

  def appointment_status_badge(appointment)
    tag.span Appointment.human_attribute_name("status.#{appointment.status}"), class: STATUS_BADGES.fetch(appointment.status)
  end
end
