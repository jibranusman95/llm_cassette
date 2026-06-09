# frozen_string_literal: true

RSpec.describe LlmCassette::Configuration do
  subject(:config) { described_class.new }

  describe "defaults" do
    it "sets cassette_directory to spec/llm_cassettes" do
      expect(config.cassette_directory).to eq("spec/llm_cassettes")
    end

    it "sets record to :none" do
      expect(config.record).to eq(:none)
    end

    it "sets replay_timing to false" do
      expect(config.replay_timing).to be(false)
    end
  end

  describe "#record=" do
    it "accepts :none" do
      config.record = :none
      expect(config.record).to eq(:none)
    end

    it "accepts :all" do
      config.record = :all
      expect(config.record).to eq(:all)
    end

    it "coerces strings to symbols" do
      config.record = "all"
      expect(config.record).to eq(:all)
    end

    it "raises for invalid modes" do
      expect { config.record = :bogus }.to raise_error(ArgumentError, /Invalid record mode/)
    end
  end
end
