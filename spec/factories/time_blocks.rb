FactoryBot.define do
  factory :time_block do
    professional
    starts_at { 1.day.from_now.change(hour: 12) }
    ends_at { starts_at + 1.hour }
  end
end
