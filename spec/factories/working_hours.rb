FactoryBot.define do
  factory :working_hour do
    professional
    day_of_week { 1 }
    start_time { "09:00" }
    end_time { "13:00" }
  end
end
