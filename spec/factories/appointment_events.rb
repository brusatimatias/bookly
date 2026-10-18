FactoryBot.define do
  factory :appointment_event do
    appointment
    to_status { "pending" }
    actor_kind { :customer }

    # The customer moved the appointment from `from` to its current time.
    trait :reschedule do
      transient { from { appointment.starts_at - 1.day } }

      from_status { "confirmed" }
      metadata { { "from_starts_at" => from.utc.iso8601, "to_starts_at" => appointment.starts_at.utc.iso8601 } }
    end
  end
end
