# Someone who books appointments. Customers have no account: within a business
# they are identified by their email.
class Customer < ApplicationRecord
  include BusinessScoped

  has_many :appointments, dependent: :restrict_with_exception

  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :name, with: ->(name) { name.squish }
  normalizes :phone, with: ->(phone) { phone.squish.presence }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { scope: :business_id }
  validates :name, presence: true, length: { maximum: 100 }
  validates :phone, length: { maximum: 30 }

  # Whether they have an active appointment whose service overlaps the range
  # (a customer can't be in two places at once, whoever the professionals).
  # `except` leaves out the appointment being moved.
  def busy_during?(range, except: nil)
    appointments.active.where.not(id: except&.id).where(starts_at: ...range.end).where("ends_at > ?", range.begin).exists?
  end
end
