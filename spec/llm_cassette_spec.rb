# frozen_string_literal: true

RSpec.describe LlmCassette do
  describe ".configure / .configuration" do
    it "returns a Configuration instance" do
      expect(described_class.configuration).to be_a(LlmCassette::Configuration)
    end

    it "yields configuration to the block" do
      described_class.configure { |c| c.replay_timing = true }
      expect(described_class.configuration.replay_timing).to be(true)
    end
  end

  describe ".current_cassette" do
    it "returns nil when no cassette is active" do
      expect(described_class.current_cassette).to be_nil
    end

    it "returns the active cassette inside use_cassette" do
      cassette_name = "test_current"
      cassette_path = File.join(described_class.configuration.cassette_directory, "#{cassette_name}.yml")
      FileUtils.rm_f(cassette_path)

      described_class.use_cassette(cassette_name, record: :all) do
        expect(described_class.current_cassette).to be_a(LlmCassette::Cassette)
        expect(described_class.current_cassette.name).to eq(cassette_name)
      end

      FileUtils.rm_f(cassette_path)
    end

    it "resets to nil after use_cassette block" do
      cassette_name = "test_after"
      cassette_path = File.join(described_class.configuration.cassette_directory, "#{cassette_name}.yml")
      FileUtils.rm_f(cassette_path)

      described_class.use_cassette(cassette_name, record: :all) { nil }
      expect(described_class.current_cassette).to be_nil

      FileUtils.rm_f(cassette_path)
    end

    it "resets to nil even when block raises" do
      cassette_name = "test_raise"
      cassette_path = File.join(described_class.configuration.cassette_directory, "#{cassette_name}.yml")
      FileUtils.rm_f(cassette_path)

      expect do
        described_class.use_cassette(cassette_name, record: :all) { raise "oops" }
      end.to raise_error("oops")

      expect(described_class.current_cassette).to be_nil
      FileUtils.rm_f(cassette_path)
    end
  end
end
