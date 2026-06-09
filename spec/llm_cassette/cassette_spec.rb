# frozen_string_literal: true

require "fileutils"
require "tmpdir"

RSpec.describe LlmCassette::Cassette do
  let(:tmpdir) { Dir.mktmpdir }
  let(:cassette_name) { "test_cassette" }
  let(:cassette_path) { File.join(tmpdir, "#{cassette_name}.yml") }

  before { LlmCassette.configure { |c| c.cassette_directory = tmpdir } }
  after  { FileUtils.rm_rf(tmpdir) }

  describe "record mode" do
    subject(:cassette) { described_class.new(cassette_name, record: :all) }

    it "starts with no interactions" do
      expect(cassette.size).to eq(0)
    end

    it "records interactions" do
      interaction = double("interaction", to_h: { "request" => {}, "response" => {} })
      cassette.record_interaction(interaction)
      expect(cassette.size).to eq(1)
    end

    it "writes a YAML file on eject" do
      interaction = LlmCassette::Interaction.from_hash(
        "request" => { "method" => "post", "uri" => "https://api.openai.com", "body" => "{}" },
        "response" => { "status" => 200, "headers" => {}, "streaming" => false, "body" => "{}" }
      )
      cassette.record_interaction(interaction)
      cassette.eject!

      expect(File.exist?(cassette_path)).to be(true)
      data = YAML.safe_load_file(cassette_path)
      expect(data["llm_cassette_version"]).to eq("1")
      expect(data["interactions"].size).to eq(1)
    end

    it "creates intermediate directories" do
      nested = described_class.new("subdir/nested", record: :all)
      nested.eject!
      expect(File.exist?(File.join(tmpdir, "subdir", "nested.yml"))).to be(true)
    end
  end

  describe "replay mode" do
    subject(:cassette) { described_class.new(cassette_name) }

    let(:interaction_data) do
      {
        "request" => { "method" => "post", "uri" => "https://api.openai.com", "body" => "{}" },
        "response" => { "status" => 200, "headers" => {}, "streaming" => false, "body" => "ok" }
      }
    end

    before do
      yaml = YAML.dump(
        "llm_cassette_version" => "1",
        "recorded_at" => Time.now.utc.iso8601,
        "interactions" => [interaction_data]
      )
      File.write(cassette_path, yaml)
    end

    it "loads interactions from file" do
      expect(cassette.size).to eq(1)
    end

    it "returns interactions sequentially" do
      interaction = cassette.next_interaction
      expect(interaction.response["body"]).to eq("ok")
    end

    it "raises NoMoreInteractionsError when exhausted" do
      cassette.next_interaction
      expect { cassette.next_interaction }.to raise_error(LlmCassette::NoMoreInteractionsError)
    end

    it "raises CassetteNotFoundError when file missing" do
      expect do
        described_class.new("nonexistent_cassette")
      end.to raise_error(LlmCassette::CassetteNotFoundError)
    end

    it "is a no-op on eject! (does not save in replay mode)" do
      expect(File).not_to receive(:write)
      cassette.eject!
    end

    it "loads a cassette with zero interactions without error" do
      empty_yaml = YAML.dump(
        "llm_cassette_version" => "1",
        "recorded_at" => Time.now.utc.iso8601,
        "interactions" => []
      )
      File.write(File.join(tmpdir, "empty.yml"), empty_yaml)
      empty_cassette = described_class.new("empty")
      expect(empty_cassette.size).to eq(0)
    end
  end
end
