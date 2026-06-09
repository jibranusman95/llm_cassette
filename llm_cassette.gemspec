# frozen_string_literal: true

require_relative "lib/llm_cassette/version"

Gem::Specification.new do |spec|
  spec.name = "llm_cassette"
  spec.version = LlmCassette::VERSION
  spec.authors = ["Jibran Usman"]
  spec.email = ["jibran.usman@eunasolutions.com"]

  spec.summary = "Streaming-aware cassette recorder for LLM calls — record once, replay fast, never hit the API in CI."
  spec.description = <<~DESC.strip
    VCR for LLMs. Hooks into Faraday (used by ruby_llm, llm.rb, and most OpenAI/Anthropic clients),
    records SSE chunks with timing, and replays them correctly. Exact-match cassettes, RSpec helpers,
    token usage stored per interaction. Works with OpenAI and Anthropic out of the box.
  DESC
  spec.homepage = "https://github.com/jibranusman95/llm_cassette"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", ">= 1.0"
end
