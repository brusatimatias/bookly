module AuthenticationHelpers
  # Signs the user in through the real login endpoint (request specs).
  def sign_in_as(user, password: "password")
    post session_path, params: { email_address: user.email_address, password: password }
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end
