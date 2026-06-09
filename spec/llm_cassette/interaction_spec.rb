# frozen_string_literal: true

RSpec.describe LlmCassette::Interaction do
  let(:request_hash) do
    { "method" => "post", "uri" => "https://api.openai.com/v1/chat/completions", "body" => "{}" }
  end

  describe ".from_hash / .to_h round-trip" do
    let(:response_hash) do
      {
        "status" => 200,
        "headers" => { "content-type" => "application/json" },
        "streaming" => false,
        "body" => FakeStreaming::OPENAI_BODY,
        "usage" => { "prompt_tokens" => 10, "completion_tokens" => 2, "total_tokens" => 12 }
      }
    end

    it "round-trips through to_h" do
      hash = { "request" => request_hash, "response" => response_hash }
      interaction = described_class.from_hash(hash)
      expect(interaction.to_h).to eq(hash)
    end
  end

  describe ".from_recording — non-streaming" do
    let(:env) do
      double("env",
             method: :post,
             url: URI("https://api.openai.com/v1/chat/completions"),
             body: "{\"model\":\"gpt-4o\"}")
    end
    let(:response) do
      double("response",
             status: 200,
             headers: { "content-type" => "application/json" },
             body: FakeStreaming::OPENAI_BODY)
    end

    it "captures method, uri, status" do
      interaction = described_class.from_recording(
        env: env, response: response, streaming: false, chunks: [], request_body: "{}"
      )
      expect(interaction.request["method"]).to eq("post")
      expect(interaction.response["status"]).to eq(200)
      expect(interaction.streaming?).to be(false)
    end

    it "extracts usage from body" do
      interaction = described_class.from_recording(
        env: env, response: response, streaming: false, chunks: [], request_body: "{}"
      )
      expect(interaction.response["usage"]["prompt_tokens"]).to eq(10)
      expect(interaction.response["usage"]["completion_tokens"]).to eq(2)
    end

    it "returns nil usage when body has no usage key" do
      no_usage_response = double("response",
                                 status: 200,
                                 headers: {},
                                 body: JSON.generate("choices" => []))
      interaction = described_class.from_recording(
        env: env, response: no_usage_response, streaming: false, chunks: [], request_body: "{}"
      )
      expect(interaction.response["usage"]).to be_nil
    end

    it "returns nil usage when body is invalid JSON" do
      bad_response = double("response", status: 200, headers: {}, body: "not json at all")
      interaction = described_class.from_recording(
        env: env, response: bad_response, streaming: false, chunks: [], request_body: "{}"
      )
      expect(interaction.response["usage"]).to be_nil
    end

    it "returns empty headers hash when response headers are nil" do
      nil_headers_response = double("response", status: 200, headers: nil, body: "{}")
      interaction = described_class.from_recording(
        env: env, response: nil_headers_response, streaming: false, chunks: [], request_body: "{}"
      )
      expect(interaction.response["headers"]).to eq({})
    end
  end

  describe "Anthropic field name mapping" do
    let(:env) do
      double("env",
             method: :post,
             url: URI("https://api.anthropic.com/v1/messages"),
             body: "{}")
    end

    it "maps input_tokens / output_tokens from a non-streaming Anthropic body" do
      anthropic_body = JSON.generate(
        "content" => [{ "text" => "Hi" }],
        "usage" => { "input_tokens" => 8, "output_tokens" => 3 }
      )
      response = double("response", status: 200, headers: {}, body: anthropic_body)
      interaction = described_class.from_recording(
        env: env, response: response, streaming: false, chunks: [], request_body: "{}"
      )
      expect(interaction.response["usage"]["prompt_tokens"]).to eq(8)
      expect(interaction.response["usage"]["completion_tokens"]).to eq(3)
    end

    it "maps input_tokens / output_tokens from streaming Anthropic chunks" do
      anthropic_chunks = [
        { data: "data: {\"type\":\"content_block_delta\",\"delta\":{\"text\":\"Hi\"}}\n\n", offset: 0.0 },
        { data: "data: {\"type\":\"message_delta\",\"usage\":{\"input_tokens\":8,\"output_tokens\":3}}\n\n",
          offset: 0.1 },
        { data: "data: {\"type\":\"message_stop\"}\n\n", offset: 0.15 }
      ]
      response = double("response", status: 200, headers: {}, body: "")
      interaction = described_class.from_recording(
        env: env, response: response, streaming: true, chunks: anthropic_chunks, request_body: "{}"
      )
      expect(interaction.response["usage"]["prompt_tokens"]).to eq(8)
      expect(interaction.response["usage"]["completion_tokens"]).to eq(3)
    end
  end

  describe ".from_recording — streaming" do
    let(:env) do
      double("env",
             method: :post,
             url: URI("https://api.openai.com/v1/chat/completions"),
             body: "{}")
    end
    let(:response) do
      double("response",
             status: 200,
             headers: { "content-type" => "text/event-stream" },
             body: "")
    end
    let(:chunks) do
      FakeStreaming::OPENAI_CHUNKS.each_with_index.map do |data, i|
        { data: data, offset: i * 0.1 }
      end
    end

    it "marks streaming as true" do
      interaction = described_class.from_recording(
        env: env, response: response, streaming: true, chunks: chunks, request_body: "{}"
      )
      expect(interaction.streaming?).to be(true)
    end

    it "stores chunks with offsets" do
      interaction = described_class.from_recording(
        env: env, response: response, streaming: true, chunks: chunks, request_body: "{}"
      )
      expect(interaction.response["chunks"].size).to eq(3)
      expect(interaction.response["chunks"].first["data"]).to include("Hello")
    end

    it "extracts usage from SSE chunks" do
      interaction = described_class.from_recording(
        env: env, response: response, streaming: true, chunks: chunks, request_body: "{}"
      )
      expect(interaction.response["usage"]["prompt_tokens"]).to eq(10)
      expect(interaction.response["usage"]["completion_tokens"]).to eq(2)
    end

    it "returns nil usage when no chunk contains a usage key" do
      no_usage_chunks = [
        { data: "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}\n\n", offset: 0.0 },
        { data: "data: [DONE]\n\n", offset: 0.1 }
      ]
      interaction = described_class.from_recording(
        env: env, response: response, streaming: true, chunks: no_usage_chunks, request_body: "{}"
      )
      expect(interaction.response["usage"]).to be_nil
    end

    it "skips chunks that do not start with 'data: '" do
      mixed_chunks = [
        { data: ": keep-alive\n\n", offset: 0.0 },
        { data: "data: {\"choices\":[{\"delta\":{\"content\":\"Hi\"}}]," \
                "\"usage\":{\"prompt_tokens\":5,\"completion_tokens\":1,\"total_tokens\":6}}\n\n",
          offset: 0.1 }
      ]
      interaction = described_class.from_recording(
        env: env, response: response, streaming: true, chunks: mixed_chunks, request_body: "{}"
      )
      expect(interaction.response["usage"]["prompt_tokens"]).to eq(5)
    end

    it "skips chunks with invalid JSON after 'data: '" do
      # reverse_each means the LAST chunk is processed first.
      # Put invalid JSON last so it is processed first in reverse, triggering the rescue.
      bad_json_chunks = [
        { data: "data: {\"choices\":[{\"delta\":{\"content\":\"Hi\"}}]," \
                "\"usage\":{\"prompt_tokens\":5,\"completion_tokens\":1,\"total_tokens\":6}}\n\n",
          offset: 0.0 },
        { data: "data: {broken json}\n\n", offset: 0.1 }
      ]
      interaction = described_class.from_recording(
        env: env, response: response, streaming: true, chunks: bad_json_chunks, request_body: "{}"
      )
      expect(interaction.response["usage"]["prompt_tokens"]).to eq(5)
    end
  end
end
