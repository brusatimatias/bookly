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
end
