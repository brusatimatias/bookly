# Development data. Idempotent: safe to run more than once (bin/rails db:seed).

Business.find_or_create_by!(slug: "barberia-centro") do |business|
  business.name = "Barbería Centro"
  business.contact_email = "hola@barberiacentro.example"
  business.contact_phone = "+54 11 5555-0101"
  business.address = "Av. Corrientes 1234, CABA"
end

Business.find_or_create_by!(slug: "downtown-studio") do |business|
  business.name = "Downtown Studio"
  business.locale = "en"
  business.time_zone = "America/New_York"
  business.currency = "USD"
  business.contact_email = "hello@downtownstudio.example"
end

# A football court: the "professionals" are its pitches, bookable by the hour.
Business.find_or_create_by!(slug: "el-potrero") do |business|
  business.name = "El Potrero Fútbol 5"
  business.contact_email = "reservas@elpotrero.example"
  business.contact_phone = "+54 11 5555-0303"
  business.address = "Av. Directorio 3200, CABA"
  business.slot_interval_minutes = 60
  business.min_booking_notice_hours = 1
  business.booking_horizon_days = 30
  business.request_expiration_hours = 6
  business.cancellation_window_hours = 12
  business.reminder_hours_before = 3
end

# Users sign in with the password "password".
def seed_member(business, role:, name:, email_address:)
  user = User.find_or_create_by!(email_address: email_address) do |new_user|
    new_user.name = name
    new_user.password = "password"
  end
  business.memberships.find_or_create_by!(user: user) { |membership| membership.role = role }
end

barberia = Business.find_by!(slug: "barberia-centro")
seed_member(barberia, role: :owner, name: "Lucía Fernández", email_address: "lucia@barberiacentro.example")
seed_member(barberia, role: :admin, name: "Diego Ruiz", email_address: "diego@barberiacentro.example")
seed_member(barberia, role: :professional, name: "Martín Gómez", email_address: "martin@barberiacentro.example")

studio = Business.find_by!(slug: "downtown-studio")
seed_member(studio, role: :owner, name: "Sam Carter", email_address: "sam@downtownstudio.example")
# Same person in two businesses with different roles.
seed_member(studio, role: :professional, name: "Martín Gómez", email_address: "martin@barberiacentro.example")

potrero = Business.find_by!(slug: "el-potrero")
seed_member(potrero, role: :owner, name: "Hernán Molina", email_address: "hernan@elpotrero.example")

# Services and professionals are per business, so they're created with the
# business as the current tenant.
def seed_service(name, duration_minutes:, price:, description:, buffer_minutes: nil)
  Service.find_or_create_by!(name: name) do |service|
    service.duration_minutes = duration_minutes
    service.price_cents = price * 100
    service.buffer_minutes = buffer_minutes
    service.description = description
  end
end

def seed_professional(name, services:, user: nil)
  professional = Professional.find_or_create_by!(name: name) { |new_professional| new_professional.user = user }
  professional.update!(services: services)
  professional
end

# Weekly hours, only for professionals that have none yet: { days => ranges },
# with days as Date#wday (0 = Sunday) and ranges as "HH:MM" pairs.
def seed_working_hours(professional, schedule)
  return if professional.working_hours.exists?

  schedule.each do |days, ranges|
    Array(days).each do |day|
      ranges.each { |start_time, end_time| professional.working_hours.create!(day_of_week: day, start_time: start_time, end_time: end_time) }
    end
  end
end

# A block between two [days from today, "HH:MM"] points in the business's
# time zone, only if the professional has no upcoming one (the dates move with
# each run).
def seed_time_block(professional, from:, to:, reason: nil)
  zone = Time.find_zone!(Current.business.time_zone)
  starts_at, ends_at = [ from, to ].map { |days, time| zone.parse("#{zone.today + days} #{time}") }

  professional.time_blocks.create!(starts_at: starts_at, ends_at: ends_at, reason: reason) unless professional.time_blocks.upcoming.exists?
end

Current.set(business: barberia) do
  haircut = seed_service("Corte de pelo", duration_minutes: 30, price: 12_000, description: "Corte con máquina y tijera, lavado incluido.")
  beard = seed_service("Arreglo de barba", duration_minutes: 20, price: 8_000, description: "Perfilado con navaja y toalla caliente.")
  combo = seed_service("Corte y barba", duration_minutes: 50, price: 18_000, buffer_minutes: 10, description: "Corte de pelo y arreglo de barba en un solo turno.")
  Service.find_or_create_by!(name: "Coloración") do |service|
    service.duration_minutes = 90
    service.price_cents = 30_000_00
    service.active = false
  end

  martin = seed_professional("Martín Gómez", services: [ haircut, beard, combo ], user: User.find_by!(email_address: "martin@barberiacentro.example"))
  # The owner also takes appointments.
  lucia = seed_professional("Lucía Fernández", services: [ haircut ], user: User.find_by!(email_address: "lucia@barberiacentro.example"))
  # Not invited yet: a profile without an account.
  sofia = seed_professional("Sofía Torres", services: [ haircut, beard ])

  seed_working_hours(martin, (1..5) => [ %w[09:00 13:00], %w[14:00 19:00] ], 6 => [ %w[09:00 14:00] ])
  seed_working_hours(lucia, (2..6) => [ %w[10:00 18:00] ])
  seed_working_hours(sofia, [ 1, 3, 5 ] => [ %w[14:00 20:00] ])

  seed_time_block(martin, from: [ 2, "16:00" ], to: [ 2, "19:00" ], reason: "Trámite")
  # Whole days: from midnight to midnight.
  seed_time_block(lucia, from: [ 7, "00:00" ], to: [ 12, "00:00" ], reason: "Vacaciones")
end

Current.set(business: studio) do
  cut = seed_service("Haircut", duration_minutes: 45, price: 40, description: "Wash, cut and style.")
  color = seed_service("Color", duration_minutes: 120, price: 110, buffer_minutes: 15, description: "Full color with a gloss finish.")

  martin = seed_professional("Martín Gómez", services: [ cut ], user: User.find_by!(email_address: "martin@barberiacentro.example"))
  alex = seed_professional("Alex Kim", services: [ cut, color ])

  seed_working_hours(martin, 6 => [ %w[10:00 16:00] ])
  seed_working_hours(alex, (1..5) => [ %w[10:00 18:00] ])

  seed_time_block(alex, from: [ 3, "12:00" ], to: [ 3, "13:00" ], reason: "Dentist")
end

Current.set(business: potrero) do
  five = seed_service("Fútbol 5 · 1 hora", duration_minutes: 60, price: 45_000,
                      description: "Cancha de césped sintético para 10 jugadores. Incluye pelota y pecheras.")
  five_long = seed_service("Fútbol 5 · 1 hora y media", duration_minutes: 90, price: 65_000,
                           description: "El mismo partido, con media hora más para el tercer tiempo adentro de la cancha.")
  seven = seed_service("Fútbol 7 · 1 hora", duration_minutes: 60, price: 70_000,
                       description: "Cancha grande para 14 jugadores, techada.")

  # Pitches, not people: profiles without an account.
  pitch_one = seed_professional("Cancha 1", services: [ five, five_long ])
  pitch_two = seed_professional("Cancha 2", services: [ five, five_long ])
  big_pitch = seed_professional("Cancha grande", services: [ seven ])

  # Ranges don't cross midnight, so the last game starts at 22:00.
  [ pitch_one, pitch_two ].each { |pitch| seed_working_hours(pitch, (0..6) => [ %w[09:00 23:00] ]) }
  seed_working_hours(big_pitch, (1..5) => [ %w[17:00 23:00] ], [ 6, 0 ] => [ %w[10:00 23:00] ])

  seed_time_block(pitch_two, from: [ 4, "09:00" ], to: [ 4, "13:00" ], reason: "Mantenimiento del césped")
end

# A few appointments in the coming days, only for businesses that have none
# yet (the dates move with each run).
def seed_appointments(appointments)
  return if Appointment.exists?

  zone = Time.find_zone!(Current.business.time_zone)
  appointments.each do |attributes|
    (days, time), name, email = attributes.values_at(:at, :name, :email)
    attributes = attributes.except(:at, :name, :email)
    customer = Customer.find_or_create_by!(email: email) { |new_customer| new_customer.name = name }
    # The next working day of that professional, from "days" ahead.
    date = (zone.today + days..).find { |day| attributes[:professional].working_hours.exists?(day_of_week: day.wday) }
    Appointment.create!(attributes.merge(customer: customer, starts_at: zone.parse("#{date} #{time}")))
  end
end

# Something to do in the panel, unless there already is: a request that
# expires in two hours, an appointment that started an hour ago, to mark its
# attendance, and a confirmed appointment the customer asked to move. Unlike
# the ones above, they're added to existing data too.
def seed_panel_examples(professional:, service:)
  zone = Time.find_zone!(Current.business.time_zone)

  unless Appointment.awaiting_answer.where("request_expires_at < ?", 3.hours.from_now).exists?
    customer = Customer.find_or_create_by!(email: "marta@example.com") { |new_customer| new_customer.name = "Marta Sosa" }
    date = (zone.today + 1..).find { |day| professional.working_hours.exists?(day_of_week: day.wday) }
    Appointment.create!(service: service, professional: professional, customer: customer, starts_at: zone.parse("#{date} 12:00"),
                        request_expires_at: 2.hours.from_now, customer_notes: "¿Puede ser con máquina?")
  end

  unless Appointment.confirmed.where(starts_at: ..Time.current).exists?
    customer = Customer.find_or_create_by!(email: "pedro@example.com") { |new_customer| new_customer.name = "Pedro Gil" }
    Appointment.create!(service: service, professional: professional, customer: customer, status: :confirmed,
                        starts_at: 1.hour.ago.in_time_zone(zone).beginning_of_hour)
  end

  unless Appointment.awaiting_answer.includes(:events).any?(&:rescheduled_from)
    customer = Customer.find_or_create_by!(email: "lucas@example.com") { |new_customer| new_customer.name = "Lucas Vera" }
    date = (zone.today + 4..).find { |day| professional.working_hours.exists?(day_of_week: day.wday) }
    appointment = Appointment.create!(service: service, professional: professional, customer: customer, starts_at: zone.parse("#{date} 09:00"))
    appointment.events.create!(to_status: "pending", actor_kind: :customer)
    appointment.confirm!(by: Current.business.owner)
    appointment.reschedule!(zone.parse("#{date} 12:00"))
  end
end

# Past outcomes, for the email previews, unless there already are: a request
# the business rejected and an appointment it cancelled, each with its reason,
# and a request nobody answered in time.
def seed_past_outcomes(professional:, service:)
  zone = Time.find_zone!(Current.business.time_zone)
  owner = Current.business.owner
  date = (zone.today + 2..).find { |day| professional.working_hours.exists?(day_of_week: day.wday) }

  unless Appointment.rejected.exists?
    customer = Customer.find_or_create_by!(email: "nora@example.com") { |new_customer| new_customer.name = "Nora Paz" }
    appointment = Appointment.create!(service: service, professional: professional, customer: customer, starts_at: zone.parse("#{date} 15:00"))
    appointment.events.create!(to_status: "pending", actor_kind: :customer)
    appointment.reject!(by: owner, reason: "Ese día cerramos temprano por una capacitación.")
  end

  unless Appointment.cancelled.joins(:events).where(appointment_events: { to_status: "cancelled", actor_kind: "user" }).exists?
    customer = Customer.find_or_create_by!(email: "tomas@example.com") { |new_customer| new_customer.name = "Tomás Ibarra" }
    appointment = Appointment.create!(service: service, professional: professional, customer: customer, starts_at: zone.parse("#{date} 16:00"))
    appointment.events.create!(to_status: "pending", actor_kind: :customer)
    appointment.confirm!(by: owner)
    appointment.cancel!(by: owner, reason: "Sofía no va a poder atender ese día; escribinos y te buscamos otro horario.")
  end

  unless Appointment.expired.exists?
    customer = Customer.find_or_create_by!(email: "irene@example.com") { |new_customer| new_customer.name = "Irene Sáenz" }
    appointment = Appointment.create!(service: service, professional: professional, customer: customer, starts_at: zone.parse("#{date} 17:00"),
                                      request_expires_at: 1.minute.ago)
    appointment.events.create!(to_status: "pending", actor_kind: :customer)
    appointment.expire!
  end
end

# The history of appointments without one: requested by the customer, then
# confirmed by the owner and, for cancelled ones, cancelled by the customer.
def seed_appointment_events
  owner = Current.business.owner
  Appointment.where.missing(:events).find_each do |appointment|
    created_at = appointment.created_at
    appointment.events.create!(to_status: "pending", actor_kind: :customer, created_at: created_at)
    next if appointment.pending?

    appointment.events.create!(from_status: "pending", to_status: "confirmed", actor_kind: :user, actor_user: owner, created_at: created_at + 1.hour)
    if appointment.cancelled?
      appointment.events.create!(from_status: "confirmed", to_status: "cancelled", actor_kind: :customer, created_at: created_at + 2.hours)
    end
  end
end

# Seeded changes email nobody: browse the emails in the previews instead
# (/rails/mailers).
AppointmentNotifier.silence do
  Current.set(business: barberia) do
    martin = Professional.find_by!(name: "Martín Gómez")
    lucia = Professional.find_by!(name: "Lucía Fernández")
    haircut = Service.find_by!(name: "Corte de pelo")
    combo = Service.find_by!(name: "Corte y barba")

    seed_appointments([
      { at: [ 1, "10:00" ], professional: martin, service: haircut, status: :confirmed, name: "Ana Pérez", email: "ana@example.com" },
      { at: [ 1, "11:00" ], professional: martin, service: combo, status: :pending, name: "Juan Ríos", email: "juan@example.com" },
      { at: [ 3, "15:00" ], professional: lucia, service: haircut, status: :confirmed, name: "Ana Pérez", email: "ana@example.com" },
      { at: [ 1, "16:00" ], professional: martin, service: haircut, status: :cancelled, name: "Carla Díaz", email: "carla@example.com" }
    ])
    seed_panel_examples(professional: martin, service: haircut)
    seed_past_outcomes(professional: Professional.find_by!(name: "Sofía Torres"), service: haircut)
    seed_appointment_events
  end

  Current.set(business: studio) do
    seed_appointments([
      { at: [ 1, "11:00" ], professional: Professional.find_by!(name: "Alex Kim"), service: Service.find_by!(name: "Color"),
        status: :confirmed, name: "Jordan Lee", email: "jordan@example.com" }
    ])
    seed_appointment_events
  end

  Current.set(business: potrero) do
    pitch_one = Professional.find_by!(name: "Cancha 1")
    five = Service.find_by!(name: "Fútbol 5 · 1 hora")

    seed_appointments([
      { at: [ 1, "20:00" ], professional: pitch_one, service: five, status: :confirmed, name: "Facundo Álvarez", email: "facundo@example.com" },
      { at: [ 1, "21:00" ], professional: Professional.find_by!(name: "Cancha 2"), service: Service.find_by!(name: "Fútbol 5 · 1 hora y media"),
        status: :pending, name: "Rocío Benítez", email: "rocio@example.com", customer_notes: "Somos de la oficina, ¿hay vestuario?" },
      { at: [ 2, "19:00" ], professional: Professional.find_by!(name: "Cancha grande"), service: Service.find_by!(name: "Fútbol 7 · 1 hora"),
        status: :confirmed, name: "Leandro Ortiz", email: "leandro@example.com" },
      { at: [ 3, "22:00" ], professional: pitch_one, service: five, status: :confirmed, name: "Facundo Álvarez", email: "facundo@example.com" }
    ])
    seed_appointment_events
  end
end
