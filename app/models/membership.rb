# Links a user with a business and their role in it. Global table: it is how a
# user reaches their businesses, so it is not BusinessScoped.
class Membership < ApplicationRecord
  belongs_to :business
  belongs_to :user

  enum :role, { owner: "owner", admin: "admin", professional: "professional" }, validate: true

  validates :user_id, uniqueness: { scope: :business_id }
  validates :role, uniqueness: { scope: :business_id, message: :owner_taken }, if: :owner?

  # Owners and admins manage the business; professionals only their own schedule.
  def manager?
    owner? || admin?
  end
end
