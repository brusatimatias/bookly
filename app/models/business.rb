class Business < ApplicationRecord
  # Lowercase words joined by single dashes. Unanchored so routes can reuse it.
  SLUG_FORMAT = /[a-z0-9]+(?:-[a-z0-9]+)*/

  # Slugs that would collide with the app's own top-level routes, since public
  # business pages live at /:business_slug.
  RESERVED_SLUGS = %w[
    admin api assets cable dashboard invitations locale login logout new
    passwords platform rails session sessions signup up
  ].freeze

  has_many :memberships, dependent: :restrict_with_exception
  has_many :members, through: :memberships, source: :user
  has_many :invitations, dependent: :restrict_with_exception
  has_one :owner_membership, -> { owner }, class_name: "Membership"
  has_one :owner, through: :owner_membership, source: :user
  # BusinessScoped: reading these still needs Current.business.
  has_many :services, dependent: :restrict_with_exception
  has_many :professionals, dependent: :restrict_with_exception
  has_many :working_hours, dependent: :restrict_with_exception
  has_many :time_blocks, dependent: :restrict_with_exception
  has_many :customers, dependent: :restrict_with_exception
  has_many :appointments, dependent: :restrict_with_exception

  enum :status, { active: "active", suspended: "suspended" }, default: :active, validate: true

  normalizes :slug, with: ->(slug) { slug.strip.downcase }
  normalizes :contact_email, with: ->(email) { email.strip.downcase }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  validates :name, presence: true
  validates :slug, presence: true,
    uniqueness: true,
    format: { with: /\A#{SLUG_FORMAT}\z/ },
    exclusion: { in: RESERVED_SLUGS, message: :reserved }
  validates :time_zone, inclusion: { in: ->(_) { TZInfo::Timezone.all_identifiers } }
  validates :locale, inclusion: { in: ->(_) { I18n.available_locales.map(&:to_s) } }
  validates :currency, presence: true

  validates :slot_interval_minutes, :request_expiration_hours, :booking_horizon_days,
    numericality: { only_integer: true, greater_than: 0 }
  validates :buffer_minutes, :cancellation_window_hours, :min_booking_notice_hours,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def to_param
    slug
  end

  def suspend!
    update!(status: :suspended, suspended_at: Time.current)
  end

  def reactivate!
    update!(status: :active, suspended_at: nil)
  end

  private
    def generate_slug
      self.slug = name.parameterize
    end
end
