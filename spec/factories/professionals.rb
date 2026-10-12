FactoryBot.define do
  factory :professional do
    sequence(:name) { |n| "Professional #{n}" }

    trait :inactive do
      active { false }
    end
  end
end
