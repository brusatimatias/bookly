FactoryBot.define do
  factory :membership do
    business
    user
    role { :professional }

    trait :owner do
      role { :owner }
    end

    trait :admin do
      role { :admin }
    end
  end
end
