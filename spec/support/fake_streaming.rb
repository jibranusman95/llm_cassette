# frozen_string_literal: true

# Builds a Faraday connection with LlmCassette::Middleware and a test adapter
# that can simulate SSE streaming by calling on_data for each chunk.
module FakeStreaming
  def self.connection(chunks: nil, body: nil, status: 200, headers: {})
    Faraday.new do |conn|
      conn.use LlmCassette::Middleware
      conn.adapter :test do |stub|
        stub.post("/v1/chat/completions") do |env|
          if chunks && env.request.on_data
            chunks.each { |c| env.request.on_data.call(c, c.bytesize) }
            [status, { "content-type" => "text/event-stream" }.merge(headers), ""]
          else
            [status, { "content-type" => "application/json" }.merge(headers), body || "{}"]
          end
        end
      end
    end
  end

  OPENAI_CHUNKS = [
    "data: {\"id\":\"chatcmpl-1\",\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}\n\n",
    "data: {\"id\":\"chatcmpl-1\",\"choices\":[{\"delta\":{\"content\":\" world\"}}]," \
    "\"usage\":{\"prompt_tokens\":10,\"completion_tokens\":2,\"total_tokens\":12}}\n\n",
    "data: [DONE]\n\n"
  ].freeze

  OPENAI_BODY = JSON.generate(
    "choices" => [{ "message" => { "content" => "Hello world" } }],
    "usage" => { "prompt_tokens" => 10, "completion_tokens" => 2, "total_tokens" => 12 }
  )
end
