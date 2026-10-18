FactoryBot.define do
  factory :appointment do
    service
    professional { association :professional, services: [ service ] }
    customer
    starts_at { 1.day.from_now.change(hour: 10) }

    trait :confirmed do
      status { :confirmed }
    end

    trait :cancelled do
      status { :cancelled }
    end
  end
end
