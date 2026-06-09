# frozen_string_literal: true

require_relative "llm_cassette/version"
require_relative "llm_cassette/errors"
require_relative "llm_cassette/configuration"
require_relative "llm_cassette/interaction"
require_relative "llm_cassette/request_signature"
require_relative "llm_cassette/cassette"
require_relative "llm_cassette/recorder"
require_relative "llm_cassette/replayer"
require_relative "llm_cassette/middleware"

module LlmCassette
  class << self
    def configure
      yield configuration
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def reset!
      @configuration = nil
    end

    def current_cassette
      Thread.current[:llm_cassette_current]
    end

    # Block form — wraps a block with an active cassette.
    #
    #   LlmCassette.use_cassette("greeting") do
    #     response = client.chat("say hello")
    #   end
    #
    # Options:
    #   record: :none (default) — replay only, raise if cassette missing
    #   record: :all            — always record (hits real API)
    def use_cassette(name, record: nil, &block)
      cassette = Cassette.new(name, record: record)
      Thread.current[:llm_cassette_current] = cassette
      begin
        block.call(cassette)
      ensure
        cassette.eject!
        Thread.current[:llm_cassette_current] = nil
      end
    end
  end
end
