# frozen_string_literal: true

require "json"

module LlmCassette
  class RequestSignature
    attr_reader :method, :uri, :body

    def initialize(env)
      @method = env.method.to_s.downcase
      @uri = env.url.to_s
      @body = normalize_body(env.body)
    end

    private

    def normalize_body(body)
      return nil unless body&.length&.positive?

      parsed = JSON.parse(body)
      JSON.generate(sort_hash(parsed))
    rescue JSON::ParserError
      body.to_s
    end

    def sort_hash(obj)
      case obj
      when Hash then obj.sort.to_h.transform_values { |v| sort_hash(v) }
      when Array then obj.map { |v| sort_hash(v) }
      else obj
      end
    end
  end
end
