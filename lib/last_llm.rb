# frozen_string_literal: true

require 'dry-schema'
require 'faraday'
require 'json'
require 'last_llm/extensions/dry_schema_extensions'

module LastLLM
  # Base error class for all LastLLM errors
  class Error < StandardError; end

  # Error raised when configuration is invalid
  class ConfigurationError < Error; end

  # Error raised when validation fails
  class ValidationError < Error; end

  # Error raised when API request fails
  class ApiError < Error
    attr_reader :status

    def initialize(message, status = nil)
      @status = status
      super(message)
    end
  end

  # Autoload all required components
  autoload :Configuration, 'last_llm/configuration'
  autoload :Client, 'last_llm/client'
  autoload :Provider, 'last_llm/provider'
  autoload :Schema, 'last_llm/schema'
  autoload :StructuredOutput, 'last_llm/structured_output'
  autoload :Tool, 'last_llm/tool'
  autoload :Railtie, 'last_llm/railtie'
  autoload :Completion, 'last_llm/completion'

  # Provider implementations
  module Providers
    autoload :OpenAI, 'last_llm/providers/openai'
    autoload :Anthropic, 'last_llm/providers/anthropic'
    autoload :GoogleGemini, 'last_llm/providers/google_gemini'
    autoload :Deepseek, 'last_llm/providers/deepseek'
    autoload :Ollama, 'last_llm/providers/ollama'
  end

  class << self
    attr_accessor :configuration

    # Configure the LastLLM client
    # @yield [config] Configuration instance
    # @return [Configuration] The updated configuration
    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
      configuration
    end

    # Get the current configuration or create a new one
    # @return [Configuration] The current configuration
    def configuration
      @configuration ||= Configuration.new
    end

    # Create a new client with the current configuration
    # @param options [Hash] Additional options for the client
    # @return [Client] A new client instance
    def client(options = {})
      Client.new(configuration, options)
    end

    # Reset the configuration to defaults
    # @return [Configuration] A new default configuration
    def reset_configuration!
      @configuration = Configuration.new
    end

    # Add Rails integration helper
    def setup_rails!
      return unless defined?(Rails)
      require 'last_llm/railtie'
    end
  end
end

# Rails integration
LastLLM.setup_rails! if defined?(Rails)
