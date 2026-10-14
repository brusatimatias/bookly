class CreateAppointmentEvents < ActiveRecord::Migration[8.1]
  STATUSES = %w[pending confirmed rejected expired cancelled attended no_show].freeze
  ACTOR_KINDS = %w[customer user system].freeze

  def change
    create_table :appointment_events do |t|
      t.references :business, null: false, foreign_key: true, index: false
      t.bigint :appointment_id, null: false
      # Null for the event that creates the appointment.
      t.string :from_status
      t.string :to_status, null: false
      t.string :actor_kind, null: false
      t.references :actor_user, foreign_key: { to_table: :users }
      # Reason for a rejection or cancellation.
      t.text :note
      # Extra details, like the previous time of a rescheduled appointment.
      t.jsonb :metadata, null: false, default: {}

      t.datetime :created_at, null: false

      statuses = STATUSES.map { |status| "'#{status}'" }.join(", ")
      t.check_constraint "from_status IS NULL OR from_status IN (#{statuses})", name: "appointment_events_from_status_valid"
      t.check_constraint "to_status IN (#{statuses})", name: "appointment_events_to_status_valid"
      t.check_constraint "actor_kind IN (#{ACTOR_KINDS.map { |kind| "'#{kind}'" }.join(", ")})", name: "appointment_events_actor_kind_valid"
      t.check_constraint "actor_kind <> 'user' OR actor_user_id IS NOT NULL", name: "appointment_events_user_actor_present"
    end

    add_index :appointment_events, %i[business_id appointment_id created_at]
    add_foreign_key :appointment_events, :appointments, column: %i[business_id appointment_id], primary_key: %i[business_id id]
  end
end
