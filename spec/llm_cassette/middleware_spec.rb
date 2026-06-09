# frozen_string_literal: true

require "fileutils"
require "tmpdir"

RSpec.describe LlmCassette::Middleware do
  let(:tmpdir) { Dir.mktmpdir }

  before { LlmCassette.configure { |c| c.cassette_directory = tmpdir } }
  after  { FileUtils.rm_rf(tmpdir) }

  describe "passthrough — no active cassette" do
    it "calls the app and returns the response normally" do
      conn = FakeStreaming.connection(body: FakeStreaming::OPENAI_BODY)
      response = conn.post("/v1/chat/completions", "{}")
      expect(response.status).to eq(200)
    end
  end

  describe "record mode (:all)" do
    it "writes a cassette file and returns the real response" do
      conn = FakeStreaming.connection(body: FakeStreaming::OPENAI_BODY)

      LlmCassette.use_cassette("record_test", record: :all) do
        response = conn.post("/v1/chat/completions", "{}")
        expect(response.status).to eq(200)
        expect(response.body).to eq(FakeStreaming::OPENAI_BODY)
      end

      cassette_file = File.join(tmpdir, "record_test.yml")
      expect(File.exist?(cassette_file)).to be(true)

      data = YAML.safe_load_file(cassette_file)
      expect(data["interactions"].size).to eq(1)
      expect(data["interactions"].first["response"]["status"]).to eq(200)
    end

    it "records streaming interactions with chunks" do
      conn = FakeStreaming.connection(chunks: FakeStreaming::OPENAI_CHUNKS)
      received = []

      LlmCassette.use_cassette("record_streaming", record: :all) do
        conn.post("/v1/chat/completions", "{}") do |req|
          req.options.on_data = proc { |chunk, _| received << chunk }
        end
      end

      data = YAML.safe_load_file(File.join(tmpdir, "record_streaming.yml"))
      interaction = data["interactions"].first
      expect(interaction["response"]["streaming"]).to be(true)
      expect(interaction["response"]["chunks"].size).to eq(3)
      expect(received).to eq(FakeStreaming::OPENAI_CHUNKS)
    end
  end

  describe "replay mode (:none)" do
    def streaming_response
      {
        "status" => 200,
        "headers" => { "content-type" => "text/event-stream" },
        "streaming" => true,
        "chunks" => FakeStreaming::OPENAI_CHUNKS.each_with_index.map { |d, i| { "data" => d, "offset" => i * 0.1 } }
      }
    end

    def non_streaming_response
      { "status" => 200, "headers" => { "content-type" => "application/json" },
        "streaming" => false, "body" => FakeStreaming::OPENAI_BODY }
    end

    def write_cassette(name, streaming: false)
      response = streaming ? streaming_response : non_streaming_response
      yaml = YAML.dump(
        "llm_cassette_version" => "1",
        "recorded_at" => Time.now.utc.iso8601,
        "interactions" => [{
          "request" => { "method" => "post", "uri" => "https://api.openai.com/v1/chat/completions", "body" => "{}" },
          "response" => response
        }]
      )
      File.write(File.join(tmpdir, "#{name}.yml"), yaml)
    end

    it "replays a non-streaming cassette without hitting the network" do
      write_cassette("replay_test")
      conn = FakeStreaming.connection # no stubs — would raise if hit

      LlmCassette.use_cassette("replay_test") do
        response = conn.post("/v1/chat/completions", "{}")
        expect(response.status).to eq(200)
        expect(response.body).to eq(FakeStreaming::OPENAI_BODY)
      end
    end

    it "replays streaming chunks via on_data" do
      write_cassette("replay_streaming", streaming: true)
      conn = FakeStreaming.connection
      received = []

      LlmCassette.use_cassette("replay_streaming") do
        conn.post("/v1/chat/completions", "{}") do |req|
          req.options.on_data = proc { |chunk, _| received << chunk }
        end
      end

      expect(received).to eq(FakeStreaming::OPENAI_CHUNKS)
    end

    it "raises CassetteNotFoundError when cassette file is missing" do
      conn = FakeStreaming.connection
      expect do
        LlmCassette.use_cassette("nonexistent") do
          conn.post("/v1/chat/completions", "{}")
        end
      end.to raise_error(LlmCassette::CassetteNotFoundError)
    end

    it "raises NoMoreInteractionsError on extra requests" do
      write_cassette("one_interaction")
      conn = FakeStreaming.connection

      expect do
        LlmCassette.use_cassette("one_interaction") do
          conn.post("/v1/chat/completions", "{}")
          conn.post("/v1/chat/completions", "{}") # second — no interaction for it
        end
      end.to raise_error(LlmCassette::NoMoreInteractionsError)
    end
  end
end
