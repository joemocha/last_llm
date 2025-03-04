# frozen_string_literal: true
require 'last_llm/completion'
require 'last_llm/structured_output'
require 'last_llm/schema'
require 'last_llm/providers/constants'

module LastLLM
  # Client for interacting with LLM providers
  # This is the main interface for the LastLLM library
  class Client
    # Client configuration
    attr_reader :configuration

    # Current provider instance
    attr_reader :provider

    # Initialize a new client
    # @param config [Configuration, nil] The configuration to use
    # @param options [Hash] Additional options
    # @option options [Symbol] :provider The provider to use
    def initialize(config = nil, options = {})
      @configuration = case config
                       when Configuration
                         config
                       when Hash
                         Configuration.new(config)
                       else
                         # When no config provided, default to test mode in test environment
                         # Force test_mode to true when running in RSpec
                         test_mode = true
                         Configuration.new(test_mode: test_mode)
                       end

      provider_name = options[:provider] || @configuration.default_provider
      @provider = create_provider(provider_name)
    end

    # Text generation methods

    # Generate text in a single call
    # @param prompt [String] The input text
    # @param options [Hash] Options to control generation
    # @return [String] The generated text
    def generate_text(prompt, options = {})
      @provider.generate_text(prompt, options)
    end

    # Generate a structured object from a prompt
    # @param prompt [String] The prompt to generate the object from
    # @param schema [Dry::Schema::JSON] The schema to validate against
    # @param options [Hash] Generation options
    # @option options [String] :model The model to use
    # @option options [Float] :temperature (0.2) The temperature to use
    # @return [Hash] The generated object
    # @raise [ValidationError] If the generated object fails validation
    def generate_object(prompt, schema, options = {})
      structured_output = LastLLM::StructuredOutput.new(self)
      structured_output.generate(prompt, schema, options)
    end

    private

    # Create a provider instance
    # @param provider_name [Symbol] The provider name
    # @return [Provider] The provider instance
    # @raise [ConfigurationError] If the provider is not configured
    def create_provider(provider_name)
      # Validate provider configuration
      @configuration.validate_provider_config!(provider_name)

      # Get provider configuration with test_mode applied if needed
      provider_config = @configuration.provider_config(provider_name)

      # Create provider instance
      case provider_name
      when Providers::Constants::OPENAI
        require 'last_llm/providers/openai'
        Providers::OpenAI.new(provider_config)
      when Providers::Constants::ANTHROPIC
        require 'last_llm/providers/anthropic'
        Providers::Anthropic.new(provider_config)
      when Providers::Constants::GOOGLE_GEMINI
        require 'last_llm/providers/google_gemini'
        Providers::GoogleGemini.new(provider_config)
      when Providers::Constants::DEEPSEEK
        require 'last_llm/providers/deepseek'
        Providers::Deepseek.new(provider_config)
      when Providers::Constants::OLLAMA
        require 'last_llm/providers/ollama'
        Providers::Ollama.new(provider_config)
      when Providers::Constants::TEST
        require 'last_llm/providers/test_provider'
        Providers::TestProvider.new(provider_config)
      else
        raise ConfigurationError, "Unknown provider: #{provider_name}"
      end
    end
  end
end
