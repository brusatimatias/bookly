# A customer's request for a free slot, from the public booking flow. Saving
# it finds or updates the customer (by email; the latest name and phone win)
# and creates a pending appointment, which already holds the time, with its
# first event. All or nothing, in one transaction.
#
# The slot is checked again against the availability, so a time taken (or
# blocked) since the customer chose it is rejected (slot_taken?). With "any
# professional" it goes to whoever is free with the fewest active appointments
# that day (then by name); if the database rejects them because someone took
# the time just now, the next free one is tried.
class AppointmentRequest
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
  attribute :email, :string
  attribute :phone, :string
  attribute :customer_notes, :string

  attr_reader :availability, :starts_at, :appointment

  validates :name, presence: true, length: { maximum: 100 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, length: { maximum: 30 }
  validates :customer_notes, length: { maximum: 500 }

  def initialize(availability:, starts_at:, **attributes)
    @availability = availability
    @starts_at = starts_at
    super(**attributes)
    self.name = name.to_s.squish.presence
    self.email = email.to_s.strip.downcase.presence
    self.phone = phone.to_s.squish.presence
    self.customer_notes = customer_notes.to_s.strip.presence
  end

  def save
    return false if invalid?

    # Its own savepoint when called inside another transaction, so a rollback
    # here undoes the customer changes too.
    Appointment.transaction(requires_new: true) do
      @appointment = nil
      customer = find_or_update_customer
      raise ActiveRecord::Rollback if overlaps_own_appointment?(customer)

      @appointment = book(customer)
      raise ActiveRecord::Rollback unless @appointment

      @appointment.events.create!(to_status: @appointment.status, actor_kind: :customer)
    end

    @appointment.present?
  end

  def slot_taken?
    errors.added?(:base, :slot_taken)
  end

  def service
    availability.service
  end

  private
    def slot
      date = starts_at.to_date
      availability.days(date..date).fetch(date, []).find { |slot| slot.starts_at == starts_at }
    end

    def find_or_update_customer
      # create_or_find_by covers two first requests with the same email at once.
      customer = Customer.find_by(email: email) ||
        Customer.create_or_find_by!(email: email) { |new_customer| new_customer.assign_attributes(name: name, phone: phone) }
      customer.update!(name: name, phone: phone || customer.phone)
      customer
    end

    # A customer can't be in two places at once, whoever the professional.
    def overlaps_own_appointment?(customer)
      ends_at = starts_at + service.duration_minutes.minutes
      overlapping = customer.appointments.active.where(starts_at: ...ends_at).where("ends_at > ?", starts_at).exists?
      errors.add(:base, :overlaps_own_appointment) if overlapping
      overlapping
    end

    # The pending appointment with the first candidate the database accepts.
    def book(customer)
      candidates.each do |professional|
        appointment = Appointment.new(service: service, professional: professional, customer: customer, starts_at: starts_at,
                                      any_professional: availability.professional.nil?, customer_notes: customer_notes)
        return appointment if appointment.save
        next if appointment.errors.added?(:base, :overlap)

        appointment.errors.each { |error| errors.add(:base, error.full_message) }
        return
      end

      errors.add(:base, :slot_taken)
      nil
    end

    # Who is free at the slot: the chosen professional, or for "any" the least
    # busy that day first.
    def candidates
      free = slot&.professionals || []
      return free if free.one? || free.empty?

      midnight = starts_at.in_time_zone(availability.zone).beginning_of_day
      day = midnight...(midnight + 1.day)
      busy = Appointment.active.where(professional_id: free.map(&:id), starts_at: day).group(:professional_id).count
      free.sort_by { |professional| [ busy.fetch(professional.id, 0), professional.name.downcase ] }
    end
end
