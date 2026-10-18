FactoryBot.define do
  factory :professional do
    sequence(:name) { |n| "Professional #{n}" }

    trait :inactive do
      active { false }
    end

    # Monday 09:00-13:00, enough to be bookable.
    trait :with_hours do
      after(:create) { |professional| create(:working_hour, professional: professional) }
    end
  end
end
