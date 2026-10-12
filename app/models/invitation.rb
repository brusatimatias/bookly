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

  enum :role, { admin: "admin", professional: "professional" }, validate: true

  attribute :expires_at, default: -> { VALID_FOR.from_now }

  normalizes :email, with: ->(email) { email.strip.downcase }

  generates_token_for :acceptance do
    [ accepted_at, expires_at ]
  end

  scope :pending, -> { where(accepted_at: nil) }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :email, uniqueness: { scope: :business_id, conditions: -> { pending }, message: :already_invited }, if: :pending?
  validate :email_not_a_member, on: :create

  def pending?
    accepted_at.nil?
  end

  def expired?
    expires_at.past?
  end

  # Adds the user to the business with the invited role. The lock keeps two
  # simultaneous acceptances from both going through.
  def accept!(user)
    with_lock do
      raise NotAcceptable unless pending? && !expired? && user.email_address == email

      business.memberships.create!(user: user, role: role)
      update!(accepted_at: Time.current)
    end
  end

  # Gives the invitation a new term. The previous link stops working.
  def renew!
    update!(expires_at: VALID_FOR.from_now)
  end

  private
    def email_not_a_member
      if business && business.members.exists?(email_address: email)
        errors.add(:email, :already_member)
      end
    end
end
