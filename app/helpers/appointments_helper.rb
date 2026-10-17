module AppointmentsHelper
  STATUS_BADGES = {
    "pending" => "badge-yellow", "confirmed" => "badge-green", "attended" => "badge-green",
    "rejected" => "badge-red", "cancelled" => "badge-red", "expired" => "badge-gray", "no_show" => "badge-gray"
  }.freeze

  # Makes the page refresh itself (morphing, keeping the scroll) when an
  # appointment of the business changes: stream is Appointment.panel_stream or
  # Appointment.availability_stream. Only for pages without forms to fill, so a
  # refresh never wipes what someone is typing.
  def refresh_on_appointment_changes(stream)
    content_for :head, turbo_refreshes_with(method: :morph, scroll: :preserve)
    turbo_stream_from(*stream)
  end

  def appointment_status_badge(appointment)
    tag.span Appointment.human_attribute_name("status.#{appointment.status}"), class: STATUS_BADGES.fetch(appointment.status)
  end

  # What an event did: "Request sent", "Confirmed", "Reassigned from Ana to
  # Pablo", "Moved from Mon 19 Oct, 12:00 to Mon 19 Oct, 10:00".
  # professional_names maps the ids in a reassignment's metadata to names.
  def appointment_event_title(event, professional_names = {})
    if event.from_status.nil?
      t("appointments.events.created")
    elsif event.reschedule?
      t("appointments.events.rescheduled", from: l(event.from_starts_at, format: :weekday_hour), to: l(event.to_starts_at, format: :weekday_hour))
    elsif event.reassignment?
      from, to = event.metadata.values_at("from_professional_id", "to_professional_id").map { |id| professional_names.fetch(id, "—") }
      t("appointments.events.reassigned", from: from, to: to)
    else
      Appointment.human_attribute_name("status.#{event.to_status}")
    end
  end

  # For a request that comes from a reschedule, a line saying so with the time
  # it had before (nil otherwise). Preload the events for lists.
  def appointment_rescheduled_note(appointment, **options)
    from = appointment.rescheduled_from or return
    # Wraps instead of truncating: the previous time is what matters.
    tag.p class: [ "flex items-start gap-1 text-xs text-brand-700", options[:class] ] do
      safe_join([ icon("arrows-right-left", class: "mt-px size-3.5 shrink-0"),
                  tag.span(t("appointments.rescheduled_from", from: l(from, format: :weekday_hour))) ])
    end
  end

  # Who made the change: the member's name, or "Customer" / "System".
  def appointment_event_actor(event)
    event.user? ? event.actor_user.name : AppointmentEvent.human_attribute_name("actor_kind.#{event.actor_kind}")
  end
end
