# frozen_string_literal: true

require 'last_llm/providers/constants'

module LastLLM
  module Providers
    # Deepseek provider implementation
    class Deepseek < LastLLM::Provider
      # API Configuration
      BASE_ENDPOINT = 'https://api.deepseek.com'
      DEFAULT_MODEL = 'deepseek-chat'

      # LLM Default Parameters
      DEFAULT_TEMPERATURE = 0.7
      DEFAULT_TOP_P = 0.8
      DEFAULT_TEMPERATURE_OBJECT = 0.2

      # Response Configuration
      SUCCESS_STATUS = 200

      # Error Status Codes
      UNAUTHORIZED_STATUS = 401
      BAD_REQUEST_STATUS = 400

      def initialize(config)
        super(Constants::DEEPSEEK, config)
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

      # Format a tool for Deepseek function calling
      # @param tool [LastLLM::Tool] The tool to format
      # @return [Hash] The tool in Deepseek format
      def self.format_tool(tool)
        {
          type: 'function',
          function: {
            name: tool.name,
            description: tool.description,
            parameters: tool.parameters
          }
        }
      end

      # Execute a tool from a Deepseek response
      # @param tool [LastLLM::Tool] The tool to execute
      # @param response [Hash] The Deepseek response containing tool call information
      # @return [Hash, nil] The result of the function call or nil if the tool wasn't called
      def self.execute_tool(tool, response)
        tool_call = response.dig(:choices, 0, :message, :tool_calls)&.first
        return nil unless tool_call && tool_call[:function][:name] == tool.name

        arguments = JSON.parse(tool_call[:function][:arguments], symbolize_names: true)
        tool.call(arguments)
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
            max_tokens: options[:max_tokens],
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
          # Try to clean markdown code blocks and parse again
          content.gsub!("```json\n", '').gsub!("\n```", '')
          begin
            JSON.parse(content, symbolize_names: true)
          rescue JSON::ParserError
            raise LastLLM::ApiError, "Invalid JSON response: #{e.message}"
          end
        end
      end

      def handle_request_error(error)
        message = "Deepseek API request failed: #{error.message}"
        status = error.respond_to?(:response) && error.response.respond_to?(:status) ? error.response.status : nil
        raise LastLLM::ApiError.new(message, status)
      end
    end
  end
end
