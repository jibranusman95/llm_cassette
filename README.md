# llm_cassette

**VCR for LLMs — streaming-aware. Record once, replay fast, never hit the API in CI.**

[![CI](https://github.com/jibranusman95/llm_cassette/actions/workflows/ci.yml/badge.svg)](https://github.com/jibranusman95/llm_cassette/actions)
[![Gem Version](https://badge.fury.io/rb/llm_cassette.svg)](https://badge.fury.io/rb/llm_cassette)
[![Downloads](https://img.shields.io/gem/dt/llm_cassette)](https://rubygems.org/gems/llm_cassette)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

Every Ruby team shipping LLM features ends up with the same problem:

```ruby
# spec/services/chat_service_spec.rb
it "returns a greeting" do
  # VCR records raw bytes — replays the entire SSE response as one blob.
  # Incremental stream processing breaks. Token counts are lost.
  # Cassettes bust on every prompt tweak.
  VCR.use_cassette("greeting") do
    result = ChatService.call("say hello")
    expect(result).to include("Hello")
  end
end
```

VCR records raw HTTP bytes. For SSE streaming it replays them all at once — your `on_data` callback fires once instead of chunk-by-chunk. Incremental stream rendering breaks. Token costs vanish. Cassettes bust on any prompt change.

Here's the same test with llm_cassette:

```ruby
it "returns a greeting" do
  LlmCassette.use_cassette("greeting") do
    result = ChatService.call("say hello")
    expect(result).to include("Hello")
  end
end
```

Chunks replay in order via `on_data`. Token usage is stored per cassette. Cassettes are human-readable YAML. Works with OpenAI, Anthropic, or any Faraday-based LLM client.

---

## What you get

**Streaming-aware replay** — records SSE chunks as an ordered sequence with wall-clock offsets. Replays them via `on_data` exactly as the real API would, so incremental stream processing works correctly in tests.

**Works without configuration** — hooks into Faraday, which both [ruby_llm](https://github.com/crmne/ruby_llm) and [llm.rb](https://github.com/kieranklaassen/llm.rb) use internally. One middleware insert and you're done.

**Token usage stored per interaction** — `response.usage.prompt_tokens`, `completion_tokens`, `total_tokens` stored in every cassette. Supports both OpenAI and Anthropic field names.

**Human-readable cassettes** — plain YAML files you can read, edit, and commit. One file per cassette, multiple interactions per file.

**RSpec helpers** — class-level `use_llm_cassette`, inline block form, and RSpec metadata — three ergonomic styles for three different situations.

---

## Install

```ruby
# Gemfile
gem "llm_cassette"
```

Add the middleware to your Faraday connection:

```ruby
# config/initializers/faraday.rb  (or wherever you build your connection)
Faraday.default_connection_options.builder_middlewares.unshift(LlmCassette::Middleware)

# Or on a specific connection:
conn = Faraday.new do |f|
  f.use LlmCassette::Middleware
  f.adapter Faraday.default_adapter
end
```

---

## Configuration

```ruby
# spec/support/llm_cassette.rb
require "llm_cassette/rspec"

LlmCassette.configure do |config|
  config.cassette_directory = Rails.root.join("spec/llm_cassettes").to_s

  # :none  — replay only. Raises CassetteNotFoundError if cassette missing (default, good for CI).
  # :all   — always hit the real API and re-record.
  config.record = ENV["LLM_RECORD"] ? :all : :none

  # Replay chunks with the original timing delays (default: false — fast CI).
  config.replay_timing = false
end
```

---

## Usage

### Block form

```ruby
LlmCassette.use_cassette("chat_greeting") do
  response = client.chat(messages: [{ role: "user", content: "say hello" }])
  expect(response.content).to include("Hello")
end
```

### Class-level helper (wraps every example in the group)

```ruby
RSpec.describe ChatService do
  use_llm_cassette "chat_service"

  it "returns a greeting" do
    expect(ChatService.call("say hello")).to include("Hello")
  end

  it "handles follow-ups" do
    # same cassette, second interaction consumed sequentially
    expect(ChatService.call("now say goodbye")).to include("Goodbye")
  end
end
```

Omit the name to auto-derive it from the example group description:

```ruby
RSpec.describe ChatService do
  use_llm_cassette  # cassette name: "chatservice"

  it "..." { ... }
end
```

### RSpec metadata

```ruby
it "greets the user", llm_cassette: "greeting" do
  expect(ChatService.call("hi")).to include("Hello")
end

# Auto-name from example description:
it "greets the user", llm_cassette: true do
  expect(ChatService.call("hi")).to include("Hello")
end
```

---

## Recording cassettes

Set `record: :all` to hit the real API and write cassette files:

```bash
LLM_RECORD=1 bundle exec rspec spec/services/chat_service_spec.rb
```

Then commit the cassette files and run with `record: :none` in CI.

To re-record a single cassette, delete its file and run with `LLM_RECORD=1` again.

---

## Cassette format

Cassettes are plain YAML — readable, diffable, and editable by hand:

```yaml
---
llm_cassette_version: "1"
recorded_at: "2026-06-09T12:00:00Z"
interactions:
  - request:
      method: post
      uri: "https://api.openai.com/v1/chat/completions"
      body: '{"messages":[{"role":"user","content":"say hello"}],"model":"gpt-4o","stream":true}'
    response:
      status: 200
      headers:
        content-type: "text/event-stream; charset=utf-8"
      streaming: true
      chunks:
        - data: "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}\n\n"
          offset: 0.0
        - data: "data: {\"choices\":[{\"delta\":{\"content\":\" world!\"}}],\"usage\":{\"prompt_tokens\":10,\"completion_tokens\":2,\"total_tokens\":12}}\n\n"
          offset: 0.134
        - data: "data: [DONE]\n\n"
          offset: 0.187
      usage:
        prompt_tokens: 10
        completion_tokens: 2
        total_tokens: 12
```

Multiple interactions in one cassette are replayed sequentially — first request gets `interactions[0]`, second gets `interactions[1]`, and so on.

---

## How streaming replay works

VCR captures raw HTTP bytes and writes them to a cassette. When it replays a streaming response, it returns the entire body at once — your `on_data` callback fires once with all the bytes. Any code that renders output incrementally as chunks arrive breaks silently.

llm_cassette records each SSE chunk separately as it arrives from `on_data`, along with its wall-clock offset from the start of the request. On replay, it calls your `on_data` proc with each chunk in sequence. The stream arrives the same way it would from the real API.

```
Real API:     on_data("data: Hello\n\n")  →  on_data("data:  world\n\n")  →  on_data("data: [DONE]\n\n")
VCR replay:   on_data("data: Hello\n\ndata:  world\n\ndata: [DONE]\n\n")   ← one call, breaks incremental rendering
llm_cassette: on_data("data: Hello\n\n")  →  on_data("data:  world\n\n")  →  on_data("data: [DONE]\n\n")
```

Enable `replay_timing: true` to also replay the inter-chunk delays for timing-sensitive tests.

---

## Why not VCR?

[vcr](https://github.com/vcr/vcr) is excellent for REST APIs — 156M downloads and well-maintained. For LLM calls specifically:

| | VCR | llm_cassette |
|---|---|---|
| SSE streaming replay | Blob — one `on_data` call | Sequential chunks via `on_data` |
| Token usage | Not captured | Stored per interaction |
| Cassette format | Marshal / YAML of raw bytes | Human-readable YAML |
| Provider knowledge | None | Extracts usage from OpenAI + Anthropic chunk formats |

If you're not using streaming and don't need token tracking, VCR works fine. llm_cassette is for teams where streaming is the default.

---

## Requirements

- Ruby >= 3.2
- Faraday >= 1.0

No Rails dependency. Works with any Ruby HTTP stack that uses Faraday.

---

## Contributing

I built this myself — which means it works great for the cases I thought of, and probably has rough edges for the ones I didn't. If you hit something weird, **open an issue**. I read them all and respond fast.

Want to fix something or add a feature? **Send a PR.** No CLA, no process overhead, no committee review. If the tests pass and the change makes sense, it's getting merged. I'm one person and I genuinely appreciate the help — you can take this further than I can alone.

Not sure where to start? Look for [`good first issue`](https://github.com/jibranusman95/llm_cassette/issues?q=label%3A%22good+first+issue%22) labels, or just open an issue and ask.

```bash
git clone https://github.com/jibranusman95/llm_cassette
cd llm_cassette
bundle install
bundle exec rspec    # all green? you're good to go
bundle exec rubocop  # no new offenses
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for full guidelines.

### Contributors

Everyone who's made this better:

<a href="https://github.com/jibranusman95/llm_cassette/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=jibranusman95/llm_cassette" />
</a>

---

## From the same author

| Gem | What it does |
|-----|-------------|
| [webhook_inbox](https://github.com/jibranusman95/webhook_inbox) | Transactional inbox for Rails webhook receivers — dedup, async processing, replay, dashboard |
| [turbo_presence](https://github.com/jibranusman95/turbo_presence) | Figma-style live cursors, avatar stacks, and typing indicators for Rails — one line |
| [promptscrub](https://github.com/jibranusman95/promptscrub) | PII redaction middleware for LLM calls |
| [http_decoy](https://github.com/jibranusman95/http_decoy) | A real Rack server that runs inside your RSpec tests — test HTTP contracts, not stubs |
| [agent_jail](https://github.com/jibranusman95/agent_jail) | Fork-based sandbox for LLM tool calls — timeout, memory limit, and filesystem restrictions |

---

## License

MIT. See [LICENSE](LICENSE).
