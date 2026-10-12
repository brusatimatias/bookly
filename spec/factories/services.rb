FactoryBot.define do
  factory :service do
    sequence(:name) { |n| "Service #{n}" }
    duration_minutes { 30 }
    price_cents { 1_000_00 }

    trait :inactive do
      active { false }
    end
  end
end
