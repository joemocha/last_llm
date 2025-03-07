# frozen_string_literal: true

require 'faraday'
require 'faraday/typhoeus'
require 'active_support/core_ext/hash/keys'

module LastLLM
  # Base class for all LLM providers
  # Implements common functionality and defines the interface that all providers must implement
  class Provider
    attr_reader :name, :config

    def initialize(name, config = {})
      @name = name
      @config = config

      if instance_of?(Provider)
        raise NotImplementedError, "#{self.class} is an abstract class and cannot be instantiated directly"
      end

      validate_config! unless config[:skip_validation]
    end

    # Generate text from a prompt
    # @param prompt [String] The prompt to generate text from
    # @param options [Hash] Generation options
    # @option options [String] :model The model to use
    # @option options [Float] :temperature (0.7) The temperature to use
    # @option options [Integer] :max_tokens The maximum number of tokens to generate
    # @return [String] The generated text
    # @raise [NotImplementedError] If not implemented by subclass
    def generate_text(prompt, options = {})
      raise NotImplementedError, "#{self.class}##{__method__} must be implemented by subclass"
    end

    # Generate a structured object from a prompt
    # @param prompt [String] The prompt to generate the object from
    # @param schema [Dry::Schema::Params] The schema to validate against
    # @param options [Hash] Generation options
    # @option options [String] :model The model to use
    # @option options [Float] :temperature (0.7) The temperature to use
    # @return [Hash] The generated object
    # @raise [NotImplementedError] If not implemented by subclass
    def generate_object(prompt, schema, options = {})
      raise NotImplementedError, "#{self.class}##{__method__} must be implemented by subclass"
    end

    # Handle request errors
    # @param error [StandardError] The error to handle
    # @raise [ApiError] A standardized API error
    def handle_request_error(error)
      status = nil
      message = "API request failed: #{error.message}"

      case error
      when Faraday::ResourceNotFound
        status = 404
      when Faraday::ConnectionFailed
        status = 503
      when Faraday::TimeoutError
        status = 504
      when Faraday::Error
        if error.respond_to?(:response) && error.response.is_a?(Hash)
          status = error.response[:status]
          body = error.response[:body]

          # Try to extract a more helpful message from the response body
          if body.is_a?(String) && !body.empty?
            begin
              parsed_body = JSON.parse(body)
              message = "API error: #{parsed_body['error']['message'] || parsed_body['error']}" if parsed_body['error']
            rescue JSON::ParserError
              # Use default message if we can't parse the body
            end
          end
        end
      end

      raise LastLLM::ApiError.new(message, status)
    end

    # Parse API response
    # @param response [HTTParty::Response] The response to parse
    # @return [Hash] The parsed response
    # @raise [ApiError] If the response is invalid
    def parse_response(response)
      return {} if response.body.nil? || response.body.empty?

      begin
        response.body.deep_symbolize_keys
      rescue JSON::ParserError
        raise LastLLM::ApiError, "Invalid JSON response: #{response.body}"
      end
    end

    private

    # Validate provider configuration
    # @raise [LastLLM::ConfigurationError] If the configuration is invalid
    def validate_config!
      raise LastLLM::ConfigurationError, 'API key is required' unless @config[:api_key]
    end

    def parse_error_body(body)
      return {} if body.nil? || body.empty?

      JSON.parse(body)
    rescue JSON::ParserError
      { 'error' => body }
    end

    def deep_symbolize_keys(hash)
      return hash unless hash.is_a?(Hash)

      hash.each_with_object({}) do |(key, value), result|
        result[key.to_sym] = case value
                             when Hash then deep_symbolize_keys(value)
                             when Array then value.map { |item| deep_symbolize_keys(item) }
                             else value
                             end
      end
    end

    protected

    def connection(base_url)
      Faraday.new(url: base_url) do |f|
        f.request :json
        f.response :json
        f.response :raise_error

        # Try to use Typhoeus if available, otherwise fall back to default adapter
        adapter = begin
          Faraday::Adapter::Typhoeus
        rescue StandardError
          Faraday.default_adapter
        end
        f.adapter adapter

        f.options.timeout = @config[:request_timeout] || 30
        f.options.open_timeout = 10
        f.options.proxy = @config[:proxy] if @config[:proxy]

        if respond_to?(:setup_authorization, true)
          setup_authorization(f)
        elsif @config[:api_key]
          f.headers['Authorization'] = "Bearer #{@config[:api_key]}"
        end
      end
    end

    def make_request(prompt, options = {})
      log_request(prompt, options)

      response = yield

      log_response(response)

      handle_response(response) do |result|
        yield(result)
      end
    rescue Faraday::Error => e
      @logger&.error("[#{@name}] Request failed: #{e.message}")
      handle_provider_error(e)
    end

    private

    def log_request(prompt, options)
      return unless @logger

      sanitized_options = options.dup
      # Remove sensitive data
      sanitized_options.delete(:api_key)

      @logger.info("[#{@name}] Request - Model: #{options[:model]}")
      @logger.debug("[#{@name}] Prompt: #{prompt}")
      @logger.debug("[#{@name}] Options: #{sanitized_options.inspect}")
    end

    def log_response(response)
      return unless @logger

      @logger.info("[#{@name}] Response received - Status: #{response.status}")
      @logger.debug("[#{@name}] Response body: #{response.body}")
    rescue StandardError => e
      @logger.error("[#{@name}] Failed to log response: #{e.message}")
    end

    def handle_provider_error(error)
      @logger&.error("[#{@name}] #{error.class}: #{error.message}")
      raise ApiError.new(error.message, error.response&.status)
    end

    def make_request(prompt, options = {})
      log_request(prompt, options)

      response = yield

      log_response(response)

      handle_response(response) do |result|
        yield(result)
      end
    rescue Faraday::Error => e
      @logger&.error("[#{@name}] Request failed: #{e.message}")
      handle_provider_error(e)
    end

    private

    def log_request(prompt, options)
      return unless @logger

      sanitized_options = options.dup
      # Remove sensitive data
      sanitized_options.delete(:api_key)

      @logger.info("[#{@name}] Request - Model: #{options[:model]}")
      @logger.debug("[#{@name}] Prompt: #{prompt}")
      @logger.debug("[#{@name}] Options: #{sanitized_options.inspect}")
    end

    def log_response(response)
      return unless @logger

      @logger.info("[#{@name}] Response received - Status: #{response.status}")
      @logger.debug("[#{@name}] Response body: #{response.body}")
    rescue StandardError => e
      @logger.error("[#{@name}] Failed to log response: #{e.message}")
    end

    def handle_provider_error(error)
      @logger&.error("[#{@name}] #{error.class}: #{error.message}")
      raise ApiError.new(error.message, error.response&.status)
    end
  end
end
