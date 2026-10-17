# A customer's move of a confirmed appointment to another time, from their
# personal link (Appointment#reschedule!). The time is checked again against
# the availability, built with `except: appointment` so the appointment's own
# time counts as free (it can move to an overlapping time). The customer can't
# overlap another of their appointments. With "any professional" it goes to
# whoever is free, the least busy first, like a new request; if the database
# rejects them because someone took the time just now, the next free one is
# tried.
#
# Raises Appointment::InvalidTransition when the appointment can no longer be
# rescheduled (no longer confirmed, or the cancellation window closed).
class AppointmentReschedule
  include ActiveModel::Model

  attr_reader :appointment, :availability, :starts_at

  def initialize(appointment:, availability:, starts_at:)
    @appointment = appointment
    @availability = availability
    @starts_at = starts_at
  end

  def save
    errors.clear
    if overlaps_own_appointment?
      errors.add(:base, :overlaps_own_appointment)
      return false
    end

    availability.candidates(starts_at).each do |professional|
      appointment.reschedule!(starts_at, professional)
      return true
    rescue ActiveRecord::RecordInvalid => error
      taken = error.record == appointment && appointment.errors.added?(:base, :overlap)
      # The transaction rolled back: the next try starts from what's saved.
      appointment.reload
      raise unless taken
    end

    errors.add(:base, :slot_taken)
    false
  end

  def slot_taken?
    errors.added?(:base, :slot_taken)
  end

  private
    def overlaps_own_appointment?
      range = starts_at...(starts_at + appointment.service.duration_minutes.minutes)
      appointment.customer.busy_during?(range, except: appointment)
    end
end
