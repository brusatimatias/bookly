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

# Users sign in with the password "password". They join their businesses in a later step.
[
  { name: "Lucía Fernández", email_address: "lucia@barberiacentro.example" },
  { name: "Sam Carter", email_address: "sam@downtownstudio.example" }
].each do |attributes|
  User.find_or_create_by!(email_address: attributes[:email_address]) do |user|
    user.name = attributes[:name]
    user.password = "password"
  end
end
