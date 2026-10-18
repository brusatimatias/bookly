FactoryBot.define do
  factory :invitation do
    business
    sequence(:email) { |n| "invitee#{n}@example.com" }
    role { :professional }
    invited_by factory: :user
  end
end
