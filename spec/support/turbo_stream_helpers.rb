# Names of Turbo streams, as broadcasts use them and as pages subscribe to them.
module TurboStreamHelpers
  def turbo_stream_name(streamables)
    Turbo::StreamsChannel.verified_stream_name(signed_turbo_stream_name(streamables))
  end

  def signed_turbo_stream_name(streamables)
    Turbo::StreamsChannel.signed_stream_name(streamables)
  end
end

RSpec.configure { |config| config.include TurboStreamHelpers }
