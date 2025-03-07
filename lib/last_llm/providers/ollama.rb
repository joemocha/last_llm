# frozen_string_literal: true

require 'last_llm/providers/constants'

module LastLLM
  module Providers
    # Ollama provider implementation
    class Ollama < LastLLM::Provider
      # API Configuration
      BASE_ENDPOINT = 'http://172.17.0.1:11434'
      DEFAULT_MODEL = 'llama3.2:latest'

      # LLM Default Parameters
      DEFAULT_TEMPERATURE = 0.7
      DEFAULT_TOP_P = 0.7
      DEFAULT_MAX_TOKENS = 24_576
      DEFAULT_TEMPERATURE_OBJECT = 0.2

      # Response Configuration
      SUCCESS_STATUS = 200

      # Error Status Codes
      SERVER_ERROR_STATUS = 500
      BAD_REQUEST_STATUS = 400

      def initialize(config)
        super(Constants::OLLAMA, config)
        @conn = connection(config[:base_url] || BASE_ENDPOINT)
      end

      def generate_text(prompt, options = {})
        make_request(prompt, options) do |result|
          result.dig(:choices, 0, :message, :content).to_s
        end
      end

      def generate_object(prompt, schema, options = {})
        system_prompt = 'You are a helpful assistant that responds with valid JSON.'
        formatted_prompt = LastLLM::StructuredOutput.format_prompt(prompt, schema)

        options = options.dup
        options[:system_prompt] = system_prompt
        options[:temperature] ||= DEFAULT_TEMPERATURE_OBJECT

        make_request(formatted_prompt, options) do |result|
          content = result.dig(:choices, 0, :message, :content)
          parse_json_response(content)
        end
      end

      # Format a tool for Ollama function calling
      # @param tool [LastLLM::Tool] The tool to format
      # @return [Hash] The tool in Ollama format
      def self.format_tool(tool)
        {
          name: tool.name,
          description: tool.description,
          parameters: tool.parameters
        }
      end

      # Execute a tool from an Ollama response
      # @param tool [LastLLM::Tool] The tool to execute
      # @param response [Hash] The Ollama response containing tool call information
      # @return [Hash, nil] The result of the function call or nil if the tool wasn't called
      def self.execute_tool(tool, response)
        # Ollama doesn't have native function calling, so we need to parse from the content
        # This is a simplified implementation that would need to be enhanced for production
        content = response.dig(:message, :content)
        return nil unless content&.include?(tool.name)

        # Simple regex to extract JSON from the content
        # This is a basic implementation and might need enhancement
        if content =~ /#{tool.name}\s*\(([^)]+)\)/i
          args_str = ::Regexp.last_match(1)
          begin
            args = JSON.parse("{#{args_str}}", symbolize_names: true)
            return tool.call(args)
          rescue JSON::ParserError
            return nil
          end
        end

        nil
      end

      private

      def make_request(prompt, options = {})
        messages = format_messages(prompt, options)

        response = @conn.post('/v1/chat/completions') do |req|
          req.body = {
            model: options[:model] || @config[:model] || DEFAULT_MODEL,
            messages: messages,
            temperature: options[:temperature] || DEFAULT_TEMPERATURE,
            top_p: options[:top_p] || DEFAULT_TOP_P,
            max_tokens: options[:max_tokens] || DEFAULT_MAX_TOKENS,
            stream: false
          }.compact
        end

        result = parse_response(response)
        yield(result)
      rescue Faraday::Error => e
        handle_request_error(e)
      end

      def format_messages(prompt, options)
        if prompt.is_a?(Array) && prompt.all? { |m| m.is_a?(Hash) && m[:role] && m[:content] }
          prompt
        elsif options[:system_prompt]
          [
            { role: 'system', content: options[:system_prompt] },
            { role: 'user', content: prompt.to_s }
          ]
        else
          [{ role: 'user', content: prompt.to_s }]
        end
      end

      def parse_json_response(content)
        begin
          JSON.parse(content, symbolize_names: true)
        rescue JSON::ParserError => e
          raise LastLLM::ApiError, "Invalid JSON response: #{e.message}"
        end
      end

      def handle_request_error(error)
        message = "Ollama API request failed: #{error.message}"
        status = error.respond_to?(:response) && error.response.respond_to?(:status) ? error.response.status : nil
        raise LastLLM::ApiError.new(message, status)
      end
    end
  end
end
