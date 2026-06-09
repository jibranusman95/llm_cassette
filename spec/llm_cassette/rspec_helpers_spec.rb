# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "llm_cassette/rspec"

# Exercises use_llm_cassette with explicit name → around block in helpers.rb
RSpec.describe "use_llm_cassette class macro (integration)" do
  use_llm_cassette "fixture"

  it "activates the cassette via the around hook" do
    expect(LlmCassette.current_cassette).not_to be_nil
    expect(LlmCassette.current_cassette.name).to eq("fixture")
  end
end

# Exercises use_llm_cassette WITHOUT a name → derive_cassette_name in helpers.rb
# Cassette name derived: "autoname_example" (fixture created at spec/fixtures/cassettes/autoname_example.yml)
RSpec.describe "autoname" do
  use_llm_cassette

  it "example" do
    expect(LlmCassette.current_cassette).not_to be_nil
    expect(LlmCassette.current_cassette.name).to eq("autoname_example")
  end
end

# Exercises llm_cassette: "name" metadata → rspec.rb around hook (else branch)
RSpec.describe "llm_cassette metadata (integration)" do
  it "activates cassette via llm_cassette: name metadata", llm_cassette: "fixture" do
    expect(LlmCassette.current_cassette).not_to be_nil
    expect(LlmCassette.current_cassette.name).to eq("fixture")
  end
end

# Exercises llm_cassette: true metadata → rspec.rb around hook (true branch + auto-name)
# Cassette name derived: "metameta_case" (fixture created at spec/fixtures/cassettes/metameta_case.yml)
RSpec.describe "metameta" do
  it "case", :llm_cassette do
    expect(LlmCassette.current_cassette).not_to be_nil
    expect(LlmCassette.current_cassette.name).to eq("metameta_case")
  end
end

RSpec.describe LlmCassette::RSpec::Helpers do
  let(:tmpdir) { Dir.mktmpdir }

  before { LlmCassette.configure { |c| c.cassette_directory = tmpdir } }
  after  { FileUtils.rm_rf(tmpdir) }

  def write_cassette(name, tmpdir)
    yaml = YAML.dump(
      "llm_cassette_version" => "1",
      "recorded_at" => Time.now.utc.iso8601,
      "interactions" => [{
        "request" => { "method" => "post", "uri" => "https://api.openai.com", "body" => "{}" },
        "response" => { "status" => 200, "headers" => {}, "streaming" => false, "body" => "cassette response" }
      }]
    )
    File.write(File.join(tmpdir, "#{name}.yml"), yaml)
  end

  describe "use_llm_cassette class helper" do
    it "activates a named cassette for each example" do
      tmpdir_ref = tmpdir
      write_cassette("named", tmpdir)

      example_group = Class.new do
        include RSpec::Matchers
        extend LlmCassette::RSpec::Helpers

        define_method(:run_in_cassette) do
          LlmCassette.configure { |c| c.cassette_directory = tmpdir_ref }
          LlmCassette.use_cassette("named") do
            expect(LlmCassette.current_cassette).not_to be_nil
            expect(LlmCassette.current_cassette.name).to eq("named")
          end
        end
      end

      expect { example_group.new.run_in_cassette }.not_to raise_error
    end
  end

  describe "LlmCassette.use_cassette block form" do
    it "exposes the cassette inside the block" do
      write_cassette("block_test", tmpdir)

      LlmCassette.use_cassette("block_test") do |cassette|
        expect(cassette).to be_a(LlmCassette::Cassette)
        expect(cassette.name).to eq("block_test")
      end
    end

    it "passes record: option through" do
      LlmCassette.use_cassette("record_opt", record: :all) do |cassette|
        expect(cassette.record?).to be(true)
      end

      FileUtils.rm_f(File.join(tmpdir, "record_opt.yml"))
    end
  end
end
