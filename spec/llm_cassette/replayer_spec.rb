# frozen_string_literal: true

RSpec.describe LlmCassette::Replayer do
  let(:url) { URI("https://api.openai.com/v1/chat/completions") }
  let(:request_options) { Faraday::RequestOptions.new }
  let(:env) do
    Faraday::Env.from(
      method: :post,
      url: url,
      request: request_options,
      request_headers: Faraday::Utils::Headers.new
    )
  end

  describe "non-streaming replay" do
    let(:interaction) do
      LlmCassette::Interaction.from_hash(
        "request" => { "method" => "post", "uri" => url.to_s, "body" => "{}" },
        "response" => {
          "status" => 200,
          "headers" => { "content-type" => "application/json" },
          "streaming" => false,
          "body" => FakeStreaming::OPENAI_BODY
        }
      )
    end

    it "returns a Faraday::Response with correct status" do
      response = described_class.new(env, interaction).call
      expect(response.status).to eq(200)
    end

    it "returns the recorded body" do
      response = described_class.new(env, interaction).call
      expect(response.body).to eq(FakeStreaming::OPENAI_BODY)
    end
  end

  describe "streaming replay" do
    let(:chunks) do
      FakeStreaming::OPENAI_CHUNKS.each_with_index.map do |data, i|
        { "data" => data, "offset" => i * 0.05 }
      end
    end
    let(:interaction) do
      LlmCassette::Interaction.from_hash(
        "request" => { "method" => "post", "uri" => url.to_s, "body" => "{}" },
        "response" => {
          "status" => 200,
          "headers" => { "content-type" => "text/event-stream" },
          "streaming" => true,
          "chunks" => chunks
        }
      )
    end

    it "calls on_data for each chunk" do
      received = []
      request_options.on_data = proc { |chunk, _bytes| received << chunk }

      described_class.new(env, interaction).call
      expect(received.size).to eq(3)
      expect(received.first).to include("Hello")
    end

    it "returns a response with joined body" do
      request_options.on_data = proc { |_c, _b| }
      response = described_class.new(env, interaction).call
      expect(response.body).to include("Hello")
    end

    it "completes without sleeping when replay_timing is false" do
      request_options.on_data = proc { |_c, _b| }
      LlmCassette.configure { |c| c.replay_timing = false }
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      described_class.new(env, interaction).call
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
      expect(elapsed).to be < 0.1
    end

    it "still returns correct response when replay_timing is true (offset 0.0)" do
      request_options.on_data = proc { |_c, _b| }
      LlmCassette.configure { |c| c.replay_timing = true }
      # All offsets are 0.0 — sleep(0.0) is a no-op, exercises the branch without real delay
      zero_offset_interaction = LlmCassette::Interaction.from_hash(
        "request" => { "method" => "post", "uri" => url.to_s, "body" => "{}" },
        "response" => {
          "status" => 200,
          "headers" => { "content-type" => "text/event-stream" },
          "streaming" => true,
          "chunks" => FakeStreaming::OPENAI_CHUNKS.map { |d| { "data" => d, "offset" => 0.0 } }
        }
      )
      response = described_class.new(env, zero_offset_interaction).call
      expect(response.status).to eq(200)
      expect(response.body).to include("Hello")
    end

    it "works when on_data is nil (no streaming consumer)" do
      # on_data not set — on_data&.call is a safe no-op
      response = described_class.new(env, interaction).call
      expect(response.status).to eq(200)
      expect(response.body).to include("Hello")
    end
  end
end
