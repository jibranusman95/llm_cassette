# frozen_string_literal: true

module LlmCassette
  module RSpec
    module Helpers
      # Class-level helper — wraps every example in the group with a cassette.
      #
      #   describe MyService do
      #     use_llm_cassette "my_service"
      #     it "..." { ... }
      #   end
      #
      # Omit the name to auto-derive it from the example group description.
      def use_llm_cassette(name = nil, **options)
        around do |example|
          cassette_name = name || example.metadata[:full_description]
                                         .gsub(%r{[^a-zA-Z0-9_\-/]}, "_")
                                         .squeeze("_")
                                         .downcase
          LlmCassette.use_cassette(cassette_name, **options) { example.run }
        end
      end
    end
  end
end
