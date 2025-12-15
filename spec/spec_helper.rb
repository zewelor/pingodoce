# frozen_string_literal: true

require "webmock/rspec"
require "dotenv/load"
require_relative "../lib/pingo_doce"

# Explicitly require error classes for tests
require_relative "../lib/pingo_doce/errors"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.order = :random

  config.before do
    PingoDoce.reset_configuration!
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("PHONE_NUMBER", anything).and_return("+351123456789")
    allow(ENV).to receive(:fetch).with("PASSWORD", anything).and_return("testpassword")
    allow(ENV).to receive(:fetch).with("DATA_DIR", anything).and_return("tmp/test_data")
    allow(ENV).to receive(:fetch).with("TIMEOUT", anything).and_return("15")
    allow(ENV).to receive(:fetch).with("LOG_LEVEL", anything).and_return("error")
  end

  config.after do
    FileUtils.rm_rf("tmp/test_data") if Dir.exist?("tmp/test_data")
  end
end

WebMock.disable_net_connect!(allow_localhost: true)
