# Signing up a business from /signup: the business and its owner's membership,
# plus the owner's account when nobody is signed in (a signed in user adds the
# business to their own). All or nothing, in one transaction. The business is
# active at once, and its contact email starts as the owner's.
class BusinessRegistration
  include ActiveModel::Model
  include ActiveModel::Attributes

  # The form's names for the business's attributes; the account's are the same
  # as the user's.
  BUSINESS_ATTRIBUTES = { name: :business_name, slug: :slug, time_zone: :time_zone, locale: :locale, currency: :currency }.freeze

  attribute :name, :string
  attribute :email_address, :string
  attribute :password, :string
  attribute :password_confirmation, :string
  attribute :business_name, :string
  attribute :slug, :string
  attribute :time_zone, :string, default: -> { Business.column_defaults["time_zone"] }
  attribute :locale, :string, default: -> { I18n.locale.to_s }
  attribute :currency, :string, default: -> { Business.column_defaults["currency"] }

  attr_reader :user, :business

  def initialize(attributes = {}, user: nil)
    @existing_user = user
    super(attributes)
  end

  # Whether the owner's account is created here (nobody was signed in).
  def new_account?
    @existing_user.nil?
  end

  def save
    @user = @existing_user || User.new(name: name, email_address: email_address, password: password, password_confirmation: password_confirmation)
    @business = Business.new(name: business_name, slug: slug.presence, time_zone: time_zone, locale: locale, currency: currency,
                             contact_email: @user.email_address)
    return false unless records_valid?

    Business.transaction do
      user.save! if new_account?
      business.save!
      business.memberships.create!(user: user, role: :owner)
    end
    true
  rescue ActiveRecord::RecordNotUnique
    # Someone took the email or the web address just now: the validations
    # say which.
    records_valid?
    false
  end

  private
    def records_valid?
      errors.clear
      user.errors.each { |error| errors.import(error) } if new_account? && user.invalid?
      business.errors.each { |error| import_business_error(error) } if business.invalid?
      errors.empty?
    end

    def import_business_error(error)
      # Without a name there's no web address to suggest either; one error is enough.
      return if error.attribute == :slug && slug.blank? && business_name.blank?

      errors.import(error, attribute: BUSINESS_ATTRIBUTES.fetch(error.attribute, :base))
    end
end
