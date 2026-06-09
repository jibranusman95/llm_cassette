# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] — 2026-06-09

### Added

- `LlmCassette::Middleware` Faraday middleware — intercepts LLM HTTP requests, routes to recorder or replayer based on active cassette and record mode.
- `LlmCassette::Cassette` — loads and saves `.yml` cassette files. Sequential interaction replay via internal index pointer. Creates intermediate directories on save.
- `LlmCassette::Interaction` — value object for a single request+response pair. Handles streaming (SSE chunk array + offsets) and non-streaming (raw body) response shapes.
- `LlmCassette::Recorder` — wraps Faraday's `on_data` callback to capture SSE chunks with wall-clock offsets. Falls back to capturing response body for non-streaming calls.
- `LlmCassette::Replayer` — replays non-streaming responses as a fake `Faraday::Response`. For streaming, emits recorded chunks via the caller's `on_data` proc. Optional timing replay via `replay_timing` config flag.
- `LlmCassette::RequestSignature` — normalizes request method, URI, and JSON body (sorted keys) for cassette storage and debugging.
- Record modes: `:none` (replay only — raises `CassetteNotFoundError` if cassette missing) and `:all` (always re-record, hits real API).
- Token usage extraction — best-effort parsing from response body (non-streaming) or last SSE chunk containing `usage` (streaming). Stored per interaction under `response.usage`.
- `LlmCassette.use_cassette("name") { }` block API — sets and clears thread-local cassette, ensures `eject!` even on exception.
- `LlmCassette::RSpec::Helpers` — `use_llm_cassette "name"` class macro wraps every example in the group via `around`. Auto-derives cassette name from example description when called without arguments.
- RSpec metadata form — `it "...", llm_cassette: "name"` and `it "...", llm_cassette: true` (auto-name). Enabled via `require "llm_cassette/rspec"`.
- `LlmCassette::CassetteNotFoundError` — raised when cassette file is missing in `:none` mode.
- `LlmCassette::NoMoreInteractionsError` — raised when a cassette is exhausted and another request is made.
- Works with OpenAI and Anthropic out of the box — provider-agnostic at the Faraday layer; usage extraction handles both `prompt_tokens`/`completion_tokens` (OpenAI) and `input_tokens`/`output_tokens` (Anthropic) field names.
