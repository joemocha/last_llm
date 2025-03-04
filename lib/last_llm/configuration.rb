# frozen_string_literal: true

require 'last_llm/providers/constants'

module LastLLM
  # Configuration class for LastLLM
  # Handles global and provider-specific settings
  class Configuration

    # Provider validation configuration
    PROVIDER_VALIDATIONS = {
      Providers::Constants::OPENAI => { required: [:api_key] },
      Providers::Constants::ANTHROPIC => { required: [:api_key] },
      Providers::Constants::GOOGLE_GEMINI => { required: [:api_key] },
      Providers::Constants::DEEPSEEK => { required: [:api_key] },
      Providers::Constants::OLLAMA => {
        required: [],
        custom: ->(config) {
          return if config[:api_key]
          raise ConfigurationError, "Ollama host is required when no API key is provided" unless config[:host]
        }
      }
    }.freeze
    # Default provider to use
    attr_accessor :default_provider

    # Default model to use
    attr_accessor :default_model

    # Provider-specific configurations
    attr_reader :providers

    attr_reader :base_url

    # Global settings
    attr_reader :globals

    # Initialize a new configuration
    # @param options [Hash] Configuration options
    # @option options [Symbol] :default_provider (:openai) The default provider to use
    # @option options [String] :default_model ('gpt-3.5-turbo') The default model to use
    # @option options [Boolean] :test_mode (false) Whether to run in test mode
    def initialize(options = {})
      @default_provider = options[:default_provider] || Providers::Constants::OPENAI
      @default_model = options[:default_model] || 'gpt-3.5-turbo'
      @test_mode = options[:test_mode] || false
      @providers = {}
      @globals = {
        timeout: 60,
        max_retries: 3,
        retry_delay: 1
      }
    end

    # Configure a provider with specific settings
    # @param provider [Symbol] The provider name
    # @param config [Hash] Provider-specific configuration
    # @return [Hash] The updated provider configuration
    def configure_provider(provider, config = {})
      @providers[provider] ||= {}
      @providers[provider].merge!(config)
    end

    # Get provider configuration
    # @param provider [Symbol] The provider name
    # @return [Hash] The provider configuration
    def provider_config(provider)
      config = @providers[provider] || {}
      # Ensure skip_validation is set when in test mode
      config = config.dup
      config[:skip_validation] = true if @test_mode
      config
    end

    # Check if running in test mode
    # @return [Boolean] Whether in test mode
    def test_mode?
      @test_mode
    end

    # Validate provider configuration based on requirements
    # @param provider [Symbol] The provider to validate
    # @raise [ConfigurationError] If the configuration is invalid
    def validate_provider_config!(provider)
      return if @test_mode

      validation = PROVIDER_VALIDATIONS[provider]
      raise ConfigurationError, "Unknown provider: #{provider}" unless validation

      config = provider_config(provider)

      if validation[:required]
        validation[:required].each do |key|
          unless config[key]
            raise ConfigurationError, "#{key.to_s.gsub('_', ' ')} is required for #{provider} provider"
          end
        end
      end

      if validation[:custom]
        validation[:custom].call(config)
      end
    end

    # Set a global configuration value
    # @param key [Symbol] The configuration key
    # @param value The configuration value
    # @return The set value
    def set_global(key, value)
      @globals[key] = value
    end

    # Get a global configuration value
    # @param key [Symbol] The configuration key
    # @return The configuration value
    def get_global(key)
      @globals[key]
    end
  end
end
