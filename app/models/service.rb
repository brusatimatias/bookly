# Something a business offers, with its duration and price. Never deleted, only
# deactivated (Deactivatable).
class Service < ApplicationRecord
  include BusinessScoped
  include Deactivatable

  # Working hours don't cross midnight, so neither can a service.
  MAX_DURATION_MINUTES = 24 * 60

  has_many :professional_services, dependent: :restrict_with_exception
  has_many :professionals, through: :professional_services

  has_rich_text :description

  # Active and offered by at least one active professional with weekly hours:
  # what customers can book.
  scope :bookable, -> { active.where(id: ProfessionalService.joins(:professional).merge(Professional.active.with_working_hours).select(:service_id)) }

  normalizes :name, with: ->(name) { name.squish }

  validates :name, presence: true, uniqueness: { scope: :business_id, case_sensitive: false }
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_DURATION_MINUTES }
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :buffer_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  # Price in the currency's main unit (12000.5), for forms. Stored in cents;
  # anything that isn't a number leaves it blank so validation catches it.
  def price
    BigDecimal(price_cents) / 100 if price_cents
  end

  def price=(value)
    amount = BigDecimal(value.to_s.strip.tr(",", "."), exception: false)
    self.price_cents = amount && (amount * 100).round
  end
end
