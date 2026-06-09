# frozen_string_literal: true

require "llm_cassette"
require "llm_cassette/rspec/helpers"

RSpec.configure do |config|
  config.extend LlmCassette::RSpec::Helpers

  # Metadata form:
  #   it "...", llm_cassette: "name" do ... end
  #   it "...", llm_cassette: true do ... end  # auto-name
  config.around(:each, :llm_cassette) do |example|
    raw = example.metadata[:llm_cassette]
    name = if raw == true
             example.metadata[:full_description]
                    .gsub(%r{[^a-zA-Z0-9_\-/]}, "_")
                    .squeeze("_")
                    .downcase
           else
             raw.to_s
           end
    LlmCassette.use_cassette(name) { example.run }
  end
end
