# frozen_string_literal: true

module LlmCassette
  class Configuration
    RECORD_MODES = %i[none all].freeze

    attr_reader :record
    attr_accessor :cassette_directory, :replay_timing

    def initialize
      @cassette_directory = "spec/llm_cassettes"
      @record = :none
      @replay_timing = false
    end

    def record=(mode)
      unless RECORD_MODES.include?(mode.to_sym)
        raise ArgumentError, "Invalid record mode: #{mode}. Must be one of: #{RECORD_MODES.join(', ')}"
      end

      @record = mode.to_sym
    end
  end
end
