# Invitation to join a business by email. Global table, like memberships.
#
# The acceptance token is not stored: it is signed by Rails and embeds
# accepted_at and expires_at, so it stops working once the invitation is
# accepted or renewed. Revoking deletes the invitation, which also voids it.
class Invitation < ApplicationRecord
  VALID_FOR = 7.days

  # Raised when accepting an invitation that was already used, expired or
  # belongs to another email.
  class NotAcceptable < StandardError; end

  belongs_to :business
  belongs_to :invited_by, class_name: "User"
  # Optional profile the new member takes over. Professional is BusinessScoped,
  # so reading it needs Current.business (accept! sets it).
  belongs_to :professional, optional: true

  enum :role, { admin: "admin", professional: "professional" }, validate: true

  attribute :expires_at, default: -> { VALID_FOR.from_now }

  normalizes :email, with: ->(email) { email.strip.downcase }

  # In UTC: the payload is compared as JSON, and times serialize with the
  # current zone's offset. Emails are rendered in the business's zone while
  # the link is checked in UTC, so zoned times would never match.
  generates_token_for :acceptance do
    [ accepted_at&.utc, expires_at.utc ]
  end

  scope :pending, -> { where(accepted_at: nil) }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :email, uniqueness: { scope: :business_id, conditions: -> { pending }, message: :already_invited }, if: :pending?
  validate :email_not_a_member, on: :create
  validates :professional_id, uniqueness: { conditions: -> { pending }, message: :already_invited }, allow_nil: true, if: :pending?
  validate :professional_not_linked, on: :create, if: :professional_id

  def pending?
    accepted_at.nil?
  end

  def expired?
    expires_at.past?
  end

  # Adds the user to the business with the invited role, and gives them their
  # professional profile: the invited one, or a new one for professionals. The
  # lock keeps two simultaneous acceptances from both going through.
  def accept!(user)
    with_lock do
      raise NotAcceptable unless pending? && !expired? && user.email_address == email

      business.memberships.create!(user: user, role: role)
      Current.set(business: business) { link_professional_profile(user) }
      update!(accepted_at: Time.current)
    end
  end

  # Gives the invitation a new term. The previous link stops working.
  def renew!
    update!(expires_at: VALID_FOR.from_now)
  end

  private
    # A profile linked to someone else in the meantime is left alone: the new
    # member then gets a profile of their own, like any invited professional
    # (professional? is the role).
    def link_professional_profile(user)
      if professional && professional.user_id.nil?
        professional.update!(user: user)
      elsif professional?
        business.professionals.create!(user: user)
      end
    end

    def professional_not_linked
      errors.add(:professional, :already_linked) if professional.user_id
    end

    def email_not_a_member
      if business && business.members.exists?(email_address: email)
        errors.add(:email, :already_member)
      end
    end
end
