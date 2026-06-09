# frozen_string_literal: true

module LlmCassette
  class Error < StandardError; end
  class CassetteNotFoundError < Error; end
  class NoMoreInteractionsError < Error; end
end
