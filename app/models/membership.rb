# Links a user with a business and their role in it. Global table: it is how a
# user reaches their businesses, so it is not BusinessScoped.
class Membership < ApplicationRecord
  # Raised when trying to remove the owner, who can't leave their business.
  class NotRemovable < StandardError; end

  belongs_to :business
  belongs_to :user

  enum :role, { owner: "owner", admin: "admin", professional: "professional" }, validate: true

  validates :user_id, uniqueness: { scope: :business_id }
  validates :role, uniqueness: { scope: :business_id, message: :owner_taken }, if: :owner?

  # Owners and admins manage the business; professionals only their own schedule.
  def manager?
    owner? || admin?
  end

  # The member's professional profile in this business, if they have one.
  def professional_profile
    Current.set(business: business) { business.professionals.find_by(user: user) }
  end

  # Removes the member from the business. The user is kept (they may belong to
  # other businesses). Their professional profile is kept too, inactive and
  # unlinked, so its history stays and it can be taken over again through an
  # invitation; unlinking also frees the foreign key to this membership.
  def remove!
    raise NotRemovable if owner?

    transaction do
      Current.set(business: business) { professional_profile&.update!(user: nil, active: false) }
      destroy!
    end
  end
end
