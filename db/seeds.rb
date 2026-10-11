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
