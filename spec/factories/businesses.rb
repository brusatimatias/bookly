FactoryBot.define do
  factory :business do
    sequence(:name) { |n| "Business #{n}" }

    trait :suspended do
      status { :suspended }
      suspended_at { Time.current }
    end
  end
end
