# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  minimum_coverage 90
end

require "json"
require "faraday"
require "llm_cassette"
require "llm_cassette/rspec/helpers"

require "support/fake_streaming"

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
  config.warnings = false
  config.order = :random
  Kernel.srand config.seed

  # Use around (not before) so config is set BEFORE any example-level around hooks fire.
  # This ensures use_llm_cassette and llm_cassette: metadata hooks see the correct
  # cassette_directory when they call Cassette.new at the start of their around block.
  config.around do |example|
    LlmCassette.reset!
    LlmCassette.configure do |c|
      c.cassette_directory = File.join(__dir__, "fixtures/cassettes")
    end
    example.run
    Thread.current[:llm_cassette_current] = nil
  end
end
