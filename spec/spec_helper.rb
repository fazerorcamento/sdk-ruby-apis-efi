# frozen_string_literal: true

require "sdk_ruby_apis_efi"
require "webmock/rspec"

# All HTTP is stubbed; never let a spec hit the real Efí APIs.
WebMock.disable_net_connect!

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.mock_with(:rspec)   { |c| c.verify_partial_doubles = true }
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  # Keep ENV changes from a single example from leaking into the others.
  config.around(:each) do |example|
    original_env = ENV.to_hash
    example.run
    ENV.replace(original_env)
  end
end
