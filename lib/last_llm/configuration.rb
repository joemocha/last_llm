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
        custom: lambda { |config|
          return if config[:api_key]
          raise ConfigurationError, 'Ollama host is required when no API key is provided' unless config[:host]
        }
      }
    }.freeze

    VALID_LOG_LEVELS = [:debug, :info, :warn, :error, :fatal].freeze

    # Default provider to use
    attr_accessor :default_provider

    # Default model to use
    attr_accessor :default_model

    # Provider-specific configurations
    attr_reader :providers

    attr_reader :base_url

    # Global settings
    attr_reader :globals

    # Logger instance
    attr_accessor :logger

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
      @provider_configs = {}
      @logger = nil
      @log_level = :info
    end

    def log_level=(level)
      level_sym = level.to_sym
      unless VALID_LOG_LEVELS.include?(level_sym)
        raise ConfigurationError, "Invalid log level: #{level}. Valid levels are: #{VALID_LOG_LEVELS.join(', ')}"
      end
      @log_level = level_sym
    end

    def log_level
      @log_level
    end

    # Configure a provider with specific settings
    # @param provider [Symbol] The provider name
    # @param config [Hash] Provider-specific configuration
    # @return [Hash] The updated provider configuration
    def configure_provider(provider, config = {})
      provider_sym = provider.to_sym
      @providers[provider_sym] ||= {}
      @providers[provider_sym].merge!(config)

      # Also update @provider_configs to maintain consistency
      @provider_configs ||= {}
      @provider_configs[provider_sym] ||= {}
      @provider_configs[provider_sym].merge!(config)
    end

    # Get provider configuration
    # @param provider [Symbol] The provider name
    # @return [Hash] The provider configuration
    def provider_config(provider)
      provider_sym = provider.to_sym
      config = @provider_configs&.dig(provider_sym) || @providers[provider_sym] || {}
      # Ensure skip_validation is set when in test mode
      config = config.dup
      config[:skip_validation] = true if @test_mode
      config
    end

    # Set configuration value for a specific provider
    def set_provider_config(provider, key, value)
      @provider_configs ||= {}
      provider_sym = provider.to_sym
      @provider_configs[provider_sym] ||= {}
      @provider_configs[provider_sym][key.to_sym] = value
    end

    # Get provider configuration value
    def get_provider_config(provider, key = nil)
      @provider_configs ||= {}
      provider_config = @provider_configs[provider.to_sym] || {}
      return provider_config if key.nil?

      provider_config[key.to_sym]
    end

    # Check if running in test mode
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

      validation[:required]&.each do |key|
        unless config[key.to_sym]
          raise ConfigurationError, "#{key.to_s.gsub('_', ' ')} is required for #{provider} provider"
        end
      end

      return unless validation[:custom]

      validation[:custom].call(config)
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
