# frozen_string_literal: true

# Base provider class for LLM providers
# This is an abstract class that should be subclassed for each provider
class Provider
  # Provider name
  attr_reader :name

  # Provider configuration
  attr_reader :config

  # Initialize a new provider
  # @param name [Symbol] The provider name
  # @param config [Hash] Provider-specific configuration
  # @raise [NotImplementedError] If instantiated directly
  def initialize(name, config = {})
    @name = name
    @config = config

    # Ensure this class is not instantiated directly
    if self.class == Provider
      raise NotImplementedError, "#{self.class} is an abstract class and cannot be instantiated directly"
    end

    # Validate configuration
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
            if parsed_body["error"]
              message = "API error: #{parsed_body["error"]["message"] || parsed_body["error"]}"
            end
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
    raise LastLLM::ConfigurationError, "API key is required" unless @config[:api_key]
  end

  def parse_error_body(body)
    return {} if body.nil? || body.empty?

    JSON.parse(body)
  rescue JSON::ParserError
    { "error" => body }
  end

  protected

  def connection(base_url)
    Faraday.new(url: base_url) do |f|
      f.request :json
      f.response :json
      f.response :raise_error
      f.adapter :typhoeus
      f.options.timeout = @config[:request_timeout] || 30
      f.options.open_timeout = 10
      f.options.proxy = @config[:proxy] if @config[:proxy]

      # Use provider-specific auth if available, otherwise fall back to default Bearer auth
      if respond_to?(:setup_authorization, true)
        setup_authorization(f)
      elsif @config[:api_key]
        f.headers['Authorization'] = "Bearer #{@config[:api_key]}"
      end

      # Add any custom headers from config
      if @config[:headers]
        @config[:headers].each do |key, value|
          f.headers[key] = value
        end
      end
    end
  end
end

# Also define it in the LastLLM namespace for consistency with Railtie
module LastLLM
  # Reference to the Provider class defined above
  Provider = ::Provider
end
