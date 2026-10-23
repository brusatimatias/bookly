class Business < ApplicationRecord
  # Lowercase words joined by single dashes. Unanchored so routes can reuse it.
  SLUG_FORMAT = /[a-z0-9]+(?:-[a-z0-9]+)*/

  # Slugs no business can take. A business's slug is the subdomain of its
  # public pages and the first segment of its panel's path (/:slug/admin), so
  # this covers the subdomains the app or its domain need (www is the domain
  # itself) and the app's own top-level routes.
  RESERVED_SLUGS = %w[
    admin api app assets blog cable dashboard docs ftp help invitations locale
    login logout mail new passwords platform rails session sessions signup
    smtp static status support up www
  ].freeze

  # Currencies a business can charge in (ISO 4217 codes).
  CURRENCIES = %w[ARS BRL CLP COP EUR MXN PEN USD UYU].freeze

  # The logo, on its public pages and customer emails. No SVG: it can carry
  # scripts.
  LOGO_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze
  LOGO_MAX_SIZE = 2.megabytes

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
  has_many :appointment_events, dependent: :restrict_with_exception

  has_one_attached :logo

  enum :status, { active: "active", suspended: "suspended" }, default: :active, validate: true

  normalizes :slug, with: ->(slug) { slug.strip.downcase }
  normalizes :contact_email, with: ->(email) { email.strip.downcase }
  normalizes :brand_color, with: ->(color) { color.strip.downcase.presence }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  validates :name, presence: true, length: { maximum: 100 }
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :contact_phone, length: { maximum: 30 }
  validates :address, length: { maximum: 200 }
  validates :slug, presence: true,
    uniqueness: true,
    format: { with: /\A#{SLUG_FORMAT}\z/ },
    exclusion: { in: RESERVED_SLUGS, message: :reserved }
  validates :time_zone, inclusion: { in: ->(_) { TZInfo::Timezone.all_identifiers } }
  validates :locale, inclusion: { in: ->(_) { I18n.available_locales.map(&:to_s) } }
  validates :currency, inclusion: { in: CURRENCIES }
  validates :brand_color, format: { with: BrandColor::FORMAT }, allow_nil: true
  validate :brand_color_readable, if: -> { brand_color&.match?(BrandColor::FORMAT) }
  validate :logo_is_an_image, if: -> { logo.attached? }

  # Upper bounds for the booking settings: generous, but they keep availability
  # from scanning years ahead or breaks longer than a working day.
  BOOKING_LIMITS = {
    slot_interval_minutes: 24 * 60,
    buffer_minutes: 24 * 60,
    min_booking_notice_hours: 30 * 24,
    booking_horizon_days: 365,
    cancellation_window_hours: 30 * 24,
    request_expiration_hours: 30 * 24,
    reminder_hours_before: 7 * 24
  }.freeze

  validates :slot_interval_minutes, :request_expiration_hours, :booking_horizon_days,
    numericality: { only_integer: true, greater_than: 0 }
  validates :buffer_minutes, :cancellation_window_hours, :min_booking_notice_hours, :reminder_hours_before,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  BOOKING_LIMITS.each do |attribute, maximum|
    validates attribute, numericality: { less_than_or_equal_to: maximum }, allow_nil: true
  end

  # Whether a host's subdomain could be a business's (it may not exist): a
  # valid slug that isn't reserved. Used by the routes to tell a business's
  # host from the app's own.
  def self.subdomain?(subdomain)
    subdomain.match?(/\A#{SLUG_FORMAT}\z/) && RESERVED_SLUGS.exclude?(subdomain)
  end

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

    def brand_color_readable
      unless BrandColor.new(brand_color).readable_with_white_text?
        errors.add(:brand_color, :low_contrast)
      end
    end

    def logo_is_an_image
      if LOGO_CONTENT_TYPES.exclude?(logo.blob.content_type)
        errors.add(:logo, :invalid_content_type)
      elsif logo.blob.byte_size > LOGO_MAX_SIZE
        errors.add(:logo, :too_large, count: LOGO_MAX_SIZE / 1.megabyte)
      end
    end
end
