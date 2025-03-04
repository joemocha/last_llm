# frozen_string_literal: true

# Constants for provider names
# This module centralizes all provider name definitions to follow DRY principles
module Constants
  OPENAI = :openai
  ANTHROPIC = :anthropic
  GOOGLE_GEMINI = :google_gemini
  DEEPSEEK = :deepseek
  OLLAMA = :ollama
  TEST = :test

  # Returns all available provider names
  # @return [Array<Symbol>] List of all provider names
  def self.all
    [OPENAI, ANTHROPIC, GOOGLE_GEMINI, DEEPSEEK, OLLAMA, TEST]
  end

  # Check if a provider name is valid
  # @param provider_name [Symbol] The provider name to check
  # @return [Boolean] Whether the provider name is valid
  def self.valid?(provider_name)
    all.include?(provider_name)
  end
end

# Also define it in the LastLLM namespace for consistency
module LastLLM
  module Providers
    # Reference to the Constants module defined above
    Constants = ::Constants
  end
end
