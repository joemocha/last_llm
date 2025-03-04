# frozen_string_literal: true

require 'last_llm/providers/constants'

# A provider implementation for testing purposes
class TestProvider < LastLLM::Provider
  attr_accessor :text_response, :object_response

  def initialize(config = {})
    # Skip parent's initialize which checks for API key
    # Instead implement our own initialization
    @config = config.is_a?(Hash) ? config : {}
    @name = Constants::TEST
    @text_response = "Test response"
    @object_response = {}
  end

  # Override validate_config! to not require API key
  def validate_config!
    # No validation needed for test provider
  end

  def generate_text(prompt, options = {})
    @text_response
  end

  def generate_object(prompt, schema, options = {})
    @object_response
  end
end

# Also define it in the LastLLM::Providers namespace for consistency
module LastLLM
  module Providers
    # Reference to the TestProvider class defined above
    TestProvider = ::TestProvider
  end
end
