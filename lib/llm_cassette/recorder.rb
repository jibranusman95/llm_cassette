# frozen_string_literal: true

module LlmCassette
  class Recorder
    def initialize(env, app, cassette)
      @env = env
      @app = app
      @cassette = cassette
    end

    def call
      request_body = @env.body.dup.to_s
      streaming = !@env.request.on_data.nil?
      chunks = intercept_streaming([], streaming)
      response = @app.call(@env)
      record(request_body, streaming, chunks, response)
      response
    end

    private

    def intercept_streaming(chunks, streaming)
      return chunks unless streaming

      original = @env.request.on_data
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @env.request.on_data = proc do |chunk, bytes|
        offset = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start).round(4)
        chunks << { data: chunk, offset: offset }
        original.call(chunk, bytes)
      end
      chunks
    end

    def record(request_body, streaming, chunks, response)
      interaction = Interaction.from_recording(
        env: @env,
        response: response,
        streaming: streaming,
        chunks: chunks,
        request_body: request_body
      )
      @cassette.record_interaction(interaction)
    end
  end
end
