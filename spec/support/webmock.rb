require "webmock/rspec"

# Block all external HTTP in tests; Cuprite needs localhost to drive Chrome.
# Google Places is stubbed per-spec (see spec/support/places_stub.rb helpers).
WebMock.disable_net_connect!(allow_localhost: true)
