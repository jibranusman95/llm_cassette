# frozen_string_literal: true

require "faraday"

module LlmCassette
  class Middleware < Faraday::Middleware
    def call(env)
      cassette = LlmCassette.current_cassette
      return app.call(env) unless cassette

      if cassette.record?
        Recorder.new(env, app, cassette).call
      else
        interaction = cassette.next_interaction
        Replayer.new(env, interaction).call
      end
    end
  end
end
