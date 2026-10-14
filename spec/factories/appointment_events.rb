FactoryBot.define do
  factory :appointment_event do
    appointment
    to_status { "pending" }
    actor_kind { :customer }
  end
end
