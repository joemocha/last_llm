# frozen_string_literal: true

require 'last_llm/providers/constants'

module LastLLM
  module Providers
    # Anthropic provider implementation
    class Anthropic < LastLLM::Provider
      # API Configuration
      BASE_ENDPOINT = 'https://api.anthropic.com'
      DEFAULT_MODEL = 'claude-3-5-haiku-latest'
      API_VERSION = '2023-06-01'

      # LLM Default Parameters
      DEFAULT_TEMPERATURE = 0.2
      DEFAULT_TOP_P = 0.8
      DEFAULT_MAX_TOKENS = 4096
      DEFAULT_MAX_TOKENS_OBJECT = 8192

      # Response Configuration
      SUCCESS_STATUS = 200

      # Error Status Codes
      UNAUTHORIZED_STATUS = 401
      BAD_REQUEST_STATUS = 400

      def initialize(config)
        super(:anthropic, config)
        @conn = connection(config[:base_url] || BASE_ENDPOINT)
        logger.debug("#{@name}: Initialized Anthropic provider with endpoint: #{config[:base_url] || BASE_ENDPOINT}")
      end

      def generate_text(prompt, options = {})
        model = get_model(options, DEFAULT_MODEL)
        logger.info("#{@name}: Generating text with model: #{model}")
        logger.debug("#{@name}: Text prompt: #{format_prompt_for_logging(prompt)}")

        make_request(prompt, options) do |result|
          response = result.dig(:content, 0, :text).to_s
          logger.debug("#{@name}: Generated response of #{response.length} characters")
          response
        end
      end

      def generate_object(prompt, schema, options = {})
        model = get_model(options, DEFAULT_MODEL)
        logger.info("#{@name}: Generating object with model: #{model}")
        logger.debug("#{@name}: Object prompt: #{format_prompt_for_logging(prompt)}")

        options = options.dup
        system_prompt = 'You are a helpful assistant that responds with valid JSON.'
        formatted_prompt = LastLLM::StructuredOutput.format_prompt(prompt, schema)

        options[:system_prompt] = system_prompt
        options[:max_tokens] ||= DEFAULT_MAX_TOKENS_OBJECT

        make_request(formatted_prompt, options) do |result|
          content = result.dig(:content, 0, :text)
          logger.debug("#{@name}: Raw JSON response: #{content}")
          parse_json_response(content)
        end
      end

      # Format a tool for Anthropic tools format
      # @param tool [LastLLM::Tool] The tool to format
      # @return [Hash] The tool in Anthropic format
      def self.format_tool(tool)
        {
          name: tool.name,
          description: tool.description,
          input_schema: tool.parameters
        }
      end

      # Execute a tool from an Anthropic response
      # @param tool [LastLLM::Tool] The tool to execute
      # @param response [Hash] The Anthropic response containing tool use information
      # @return [Hash, nil] The result of the function call or nil if the tool wasn't used
      def self.execute_tool(tool, response)
        tool_use = response[:tool_use]
        return nil unless tool_use && tool_use[:name] == tool.name

        tool.call(tool_use[:input])
      end

      private

      def format_prompt_for_logging(prompt)
        if prompt.is_a?(Array)
          prompt.map { |m| m[:content] }.join('...')
        else
          truncate_text(prompt.to_s)
        end
      end

      def truncate_text(text, length = 100)
        text.length > length ? "#{text[0...length]}..." : text
      end

      def get_model(options, default)
        options[:model] || @config[:model] || default
      end

      def make_request(prompt, options = {})
        messages = format_messages(prompt, options)
        model = get_model(options, DEFAULT_MODEL)

        logger.debug("#{@name}: Making API request to model: #{model}")

        body = {
          model: model,
          messages: messages,
          max_tokens: options[:max_tokens] || DEFAULT_MAX_TOKENS,
          temperature: options[:temperature] || DEFAULT_TEMPERATURE,
          top_p: options[:top_p] || DEFAULT_TOP_P,
          stream: false
        }

        # Add system parameter if system prompt is provided
        body[:system] = options[:system_prompt] if options[:system_prompt]
        logger.debug("#{@name}: Request body: #{body.compact.inspect}")

        response = @conn.post('/v1/messages') do |req|
          req.body = body.compact
        end

        logger.info("#{@name}: API response status: #{response.status}")
        result = parse_response(response)
        yield(result)
      rescue Faraday::Error => e
        logger.error("#{@name}: API request failed: #{e.message}")
        handle_request_error(e)
      end

      def format_messages(prompt, options)
        if prompt.is_a?(Array) && prompt.all? { |m| m.is_a?(Hash) && m[:role] && m[:content] }
          # Extract system message if present
          system_messages = prompt.select { |m| m[:role] == 'system' }

          # Set system_prompt if a system message was found
          if system_messages.any? && !options[:system_prompt]
            options[:system_prompt] = system_messages.map { |m| m[:content] }.join("\n")
          end

          # Return only non-system messages
          prompt.reject { |m| m[:role] == 'system' }
        else
          [{ role: 'user', content: prompt.to_s }]
        end
      end

      def parse_json_response(content)
        logger.debug("#{@name}: Parsing JSON response")
        begin
          JSON.parse(content, symbolize_names: true)
        rescue JSON::ParserError => e
          logger.error("#{@name}: JSON parsing error: #{e.message}")
          raise ApiError, "Invalid JSON response: #{e.message}"
        end
      end

      def setup_authorization(conn)
        conn.headers['x-api-key'] = @config[:api_key]
        conn.headers['anthropic-version'] = API_VERSION
      end

      def handle_request_error(e)
        message = "#{@name}: API request failed: #{e.message}"
        status = e.respond_to?(:response) && e.response.respond_to?(:status) ? e.response.status : nil
        logger.error(message)
        raise LastLLM::ApiError.new(message, status)
      end
    end
  end
end
