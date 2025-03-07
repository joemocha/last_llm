# frozen_string_literal: true

require 'last_llm/providers/constants'

module LastLLM
  module Providers
    # A provider implementation for testing purposes
    class TestProvider < LastLLM::Provider
      # API Configuration (not used for testing but included for consistency)
      BASE_ENDPOINT = 'http://test.example.com'
      DEFAULT_MODEL = 'test-model'

      # Default response values
      DEFAULT_TEXT_RESPONSE = 'Test response'
      DEFAULT_OBJECT_RESPONSE = {}

      attr_accessor :text_response, :object_response

      def initialize(config = {})
        # Skip parent's initialize which checks for API key
        # Instead implement our own initialization
        @config = config.is_a?(Hash) ? config : {}
        @name = Constants::TEST
        @text_response = DEFAULT_TEXT_RESPONSE
        @object_response = DEFAULT_OBJECT_RESPONSE
      end

      # Override validate_config! to not require API key
      def validate_config!
        # No validation needed for test provider
      end

      def generate_text(_prompt, _options = {})
        @text_response
      end

      def generate_object(_prompt, _schema, _options = {})
        @object_response
      end

      # Format a tool for the test provider
      # @param tool [LastLLM::Tool] The tool to format
      # @return [Hash] The tool in test format
      def self.format_tool(tool)
        {
          name: tool.name,
          description: tool.description,
          parameters: tool.parameters
        }
      end

      # Execute a test tool
      # @param tool [LastLLM::Tool] The tool to execute
      # @param _response [Hash] Not used in test provider
      # @return [Hash, nil] Always returns nil in test provider
      def self.execute_tool(tool, _response)
        nil # Test provider doesn't execute tools by default
      end
    end
  end
end
