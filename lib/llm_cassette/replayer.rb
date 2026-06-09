# frozen_string_literal: true

require "faraday"

module LlmCassette
  class Replayer
    def initialize(env, interaction)
      @env = env
      @interaction = interaction
    end

    def call
      if @interaction.streaming?
        replay_streaming
      else
        replay_non_streaming
      end
    end

    private

    def replay_streaming
      on_data = @env.request.on_data
      chunks = @interaction.response["chunks"] || []

      chunks.each do |chunk|
        data = chunk["data"].to_s
        sleep(chunk["offset"].to_f) if LlmCassette.configuration.replay_timing && chunk["offset"].to_f.positive?
        on_data&.call(data, data.bytesize)
      end

      build_response(
        status: @interaction.response["status"],
        headers: @interaction.response["headers"],
        body: chunks.map { |c| c["data"].to_s }.join
      )
    end

    def replay_non_streaming
      build_response(
        status: @interaction.response["status"],
        headers: @interaction.response["headers"],
        body: @interaction.response["body"].to_s
      )
    end

    def build_response(status:, headers:, body:)
      env = @env.dup
      env.status = status.to_i
      env.response_headers = Faraday::Utils::Headers.new(headers || {})
      env.body = body
      Faraday::Response.new(env)
    end
  end
end
