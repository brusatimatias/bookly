# A bookable person in a business. The profile can exist on its own (created by
# a manager) or be linked to a member's account, which lets that person sign in
# and manage their schedule. Never deleted, only deactivated (Deactivatable).
class Professional < ApplicationRecord
  include BusinessScoped
  include Deactivatable

  PHOTO_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze
  PHOTO_MAX_SIZE = 5.megabytes

  belongs_to :user, optional: true

  has_many :professional_services, dependent: :restrict_with_exception
  has_many :services, through: :professional_services
  has_many :working_hours, dependent: :restrict_with_exception
  has_many :time_blocks, dependent: :restrict_with_exception
  has_many :appointments, dependent: :restrict_with_exception

  has_one_attached :photo

  scope :with_working_hours, -> { where(id: WorkingHour.select(:professional_id)) }
  # Active, offering at least one active service and with weekly hours: who
  # customers can book.
  scope :bookable, -> { active.with_working_hours.where(id: ProfessionalService.joins(:service).merge(Service.active).select(:professional_id)) }

  normalizes :name, with: ->(name) { name.squish }

  before_validation :take_name_from_user, if: -> { name.blank? && user }

  validates :name, presence: true
  validates :user_id, uniqueness: { scope: :business_id, message: :already_linked }, allow_nil: true
  validate :user_is_member, if: -> { user_id.present? && user_id_changed? }
  validate :photo_is_an_image, if: -> { photo.attached? }

  # Customers can only book active professionals that offer an active service
  # and have weekly hours.
  def bookable?
    active? && services.any?(&:active?) && working_hours.any?
  end

  private
    def take_name_from_user
      self.name = user.name
    end

    # Mirrors the composite foreign key to memberships with a readable error.
    def user_is_member
      errors.add(:user, :not_a_member) unless Membership.exists?(business_id: business_id, user_id: user_id)
    end

    def photo_is_an_image
      if PHOTO_CONTENT_TYPES.exclude?(photo.blob.content_type)
        errors.add(:photo, :invalid_content_type)
      elsif photo.blob.byte_size > PHOTO_MAX_SIZE
        errors.add(:photo, :too_large, count: PHOTO_MAX_SIZE / 1.megabyte)
      end
    end
end
