class RequireReasonForTeamDecisions < ActiveRecord::Migration[8.1]
  def change
    # The business must say why it rejects or cancels an appointment.
    add_check_constraint :appointment_events,
      "actor_kind <> 'user' OR to_status NOT IN ('rejected', 'cancelled') OR length(btrim(coalesce(note, ''))) > 0",
      name: "appointment_events_team_reason_present"
  end
end
