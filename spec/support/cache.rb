# The test cache lives in memory (rate limits use it): start each example empty.
RSpec.configure do |config|
  config.before { Rails.cache.clear }
end
