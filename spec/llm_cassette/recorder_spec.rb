# frozen_string_literal: true

RSpec.describe LlmCassette::Recorder do
  let(:cassette) { instance_double(LlmCassette::Cassette, record?: true) }

  describe "non-streaming recording" do
    it "records the interaction and passes response through" do
      conn = FakeStreaming.connection(body: FakeStreaming::OPENAI_BODY)

      allow(cassette).to receive(:record_interaction)
      Thread.current[:llm_cassette_current] = cassette

      response = conn.post("/v1/chat/completions", "{}")
      expect(response.status).to eq(200)
      expect(cassette).to have_received(:record_interaction) do |interaction|
        expect(interaction.streaming?).to be(false)
        expect(interaction.response["body"]).to eq(FakeStreaming::OPENAI_BODY)
      end
    ensure
      Thread.current[:llm_cassette_current] = nil
    end
  end

  describe "streaming recording" do
    it "captures chunks and passes them to the original on_data callback" do
      conn = FakeStreaming.connection(chunks: FakeStreaming::OPENAI_CHUNKS)

      allow(cassette).to receive(:record_interaction)
      Thread.current[:llm_cassette_current] = cassette

      received = []
      conn.post("/v1/chat/completions", "{}") do |req|
        req.options.on_data = proc { |chunk, _bytes| received << chunk }
      end

      expect(received).to eq(FakeStreaming::OPENAI_CHUNKS)
      expect(cassette).to have_received(:record_interaction) do |interaction|
        expect(interaction.streaming?).to be(true)
        expect(interaction.response["chunks"].size).to eq(3)
      end
    ensure
      Thread.current[:llm_cassette_current] = nil
    end
  end
end
