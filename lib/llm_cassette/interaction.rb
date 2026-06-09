# frozen_string_literal: true

require "json"

module LlmCassette
  class Interaction
    attr_reader :request, :response

    def initialize(request:, response:)
      @request = request
      @response = response
    end

    def self.from_recording(env:, response:, streaming:, chunks:, request_body:)
      req = {
        "method" => env.method.to_s.downcase,
        "uri" => env.url.to_s,
        "body" => request_body
      }

      res = build_response_hash(response, streaming, chunks)

      new(request: req, response: res)
    end

    def self.from_hash(hash)
      new(request: hash["request"], response: hash["response"])
    end

    def to_h
      { "request" => request, "response" => response }
    end

    def streaming?
      response["streaming"] == true
    end

    class << self
      private

      def build_response_hash(response, streaming, chunks)
        res = {
          "status" => response.status,
          "headers" => normalize_headers(response.headers),
          "streaming" => streaming
        }

        if streaming
          serialized = chunks.map { |c| { "data" => c[:data], "offset" => c[:offset] } }
          res["chunks"] = serialized
          res["usage"] = extract_usage_from_chunks(chunks)
        else
          res["body"] = response.body.to_s
          res["usage"] = extract_usage_from_body(response.body)
        end

        res
      end

      def normalize_headers(headers)
        return {} unless headers

        headers.each_with_object({}) { |(k, v), h| h[k.to_s.downcase] = v }
      end

      def extract_usage_from_body(body)
        return nil unless body&.length&.positive?

        parsed = JSON.parse(body)
        usage = parsed["usage"]
        return nil unless usage

        build_usage_hash(usage)
      rescue JSON::ParserError
        nil
      end

      def extract_usage_from_chunks(chunks)
        chunks.reverse_each do |chunk|
          data = chunk[:data].to_s
          next unless data.start_with?("data: ")

          json_str = data.sub(/\Adata: /, "").strip
          next if json_str == "[DONE]"

          parsed = JSON.parse(json_str)
          usage = parsed["usage"]
          next unless usage

          return build_usage_hash(usage)
        rescue JSON::ParserError
          next
        end
        nil
      end

      def build_usage_hash(usage)
        {
          "prompt_tokens" => usage["prompt_tokens"] || usage["input_tokens"],
          "completion_tokens" => usage["completion_tokens"] || usage["output_tokens"],
          "total_tokens" => usage["total_tokens"]
        }.compact
      end
    end
  end
end
