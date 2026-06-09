# frozen_string_literal: true

RSpec.describe LlmCassette::RequestSignature do
  def make_env(body)
    double("env",
           method: :post,
           url: URI("https://api.openai.com/v1/chat/completions"),
           body: body)
  end

  describe "#method / #uri" do
    it "downcases the method" do
      sig = described_class.new(make_env("{}"))
      expect(sig.method).to eq("post")
    end

    it "captures the full URI" do
      sig = described_class.new(make_env("{}"))
      expect(sig.uri).to eq("https://api.openai.com/v1/chat/completions")
    end
  end

  describe "#body normalization" do
    it "sorts JSON keys" do
      sig = described_class.new(make_env('{"z":1,"a":2}'))
      parsed = JSON.parse(sig.body)
      expect(parsed.keys).to eq(%w[a z])
    end

    it "sorts keys recursively in nested objects" do
      sig = described_class.new(make_env('{"model":"gpt-4o","messages":[{"role":"user","content":"hi"}]}'))
      parsed = JSON.parse(sig.body)
      expect(parsed.keys.first).to eq("messages") # m < mo alphabetically
      expect(parsed["messages"].first.keys).to eq(%w[content role])
    end

    it "handles JSON arrays at the top level of values" do
      sig = described_class.new(make_env('{"tools":[{"name":"search"},{"name":"calc"}]}'))
      parsed = JSON.parse(sig.body)
      expect(parsed["tools"]).to be_an(Array)
      expect(parsed["tools"].first.keys).to eq(["name"])
    end

    it "returns raw string when body is not JSON" do
      sig = described_class.new(make_env("raw body"))
      expect(sig.body).to eq("raw body")
    end

    it "returns nil when body is nil" do
      sig = described_class.new(make_env(nil))
      expect(sig.body).to be_nil
    end

    it "returns nil when body is empty" do
      sig = described_class.new(make_env(""))
      expect(sig.body).to be_nil
    end
  end
end
