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

  seed_professional("Martín Gómez", services: [ haircut, beard, combo ], user: User.find_by!(email_address: "martin@barberiacentro.example"))
  # The owner also takes appointments.
  seed_professional("Lucía Fernández", services: [ haircut ], user: User.find_by!(email_address: "lucia@barberiacentro.example"))
  # Not invited yet: a profile without an account.
  seed_professional("Sofía Torres", services: [ haircut, beard ])
end

Current.set(business: studio) do
  cut = seed_service("Haircut", duration_minutes: 45, price: 40, description: "Wash, cut and style.")
  color = seed_service("Color", duration_minutes: 120, price: 110, buffer_minutes: 15, description: "Full color with a gloss finish.")

  seed_professional("Martín Gómez", services: [ cut ], user: User.find_by!(email_address: "martin@barberiacentro.example"))
  seed_professional("Alex Kim", services: [ cut, color ])
end
