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
  validate :owner_role_unchanged, on: :update, if: :role_changed?

  # Owners and admins manage the business; professionals only their own schedule.
  def manager?
    owner? || admin?
  end

  # Whether the member can answer and manage an appointment (confirm, reject,
  # cancel, attendance): owners and admins any, professionals their own.
  # Reassigning is for owners and admins only (manager?).
  def manages_appointment?(appointment)
    manager? || appointment.professional.user_id == user_id
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

  # Switches the member between admin and professional. New professionals get
  # a profile, like invited ones; admins keep theirs, since they can be
  # bookable too. Returns false when the role can't change (owners).
  def change_role(new_role)
    self.role = new_role
    return false unless valid?

    transaction do
      save!
      Current.set(business: business) { business.professionals.create!(user: user) } if professional? && !professional_profile
    end
    true
  end

  private
    # Ownership isn't transferred: nobody becomes or stops being the owner.
    def owner_role_unchanged
      errors.add(:role, :owner_unchangeable) if owner? || role_was == "owner"
    end
end
