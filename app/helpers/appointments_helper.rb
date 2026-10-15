module AppointmentsHelper
  STATUS_BADGES = {
    "pending" => "badge-yellow", "confirmed" => "badge-green", "attended" => "badge-green",
    "rejected" => "badge-red", "cancelled" => "badge-red", "expired" => "badge-gray", "no_show" => "badge-gray"
  }.freeze

  def appointment_status_badge(appointment)
    tag.span Appointment.human_attribute_name("status.#{appointment.status}"), class: STATUS_BADGES.fetch(appointment.status)
  end

  # What an event did: "Request sent", "Confirmed", "Reassigned: Ana → Pablo".
  # professional_names maps the ids in a reassignment's metadata to names.
  def appointment_event_title(event, professional_names = {})
    if event.from_status.nil?
      t("appointments.events.created")
    elsif event.metadata.key?("to_professional_id")
      from, to = event.metadata.values_at("from_professional_id", "to_professional_id").map { |id| professional_names.fetch(id, "—") }
      t("appointments.events.reassigned", from: from, to: to)
    else
      Appointment.human_attribute_name("status.#{event.to_status}")
    end
  end

  # Who made the change: the member's name, or "Customer" / "System".
  def appointment_event_actor(event)
    event.user? ? event.actor_user.name : AppointmentEvent.human_attribute_name("actor_kind.#{event.actor_kind}")
  end
end
