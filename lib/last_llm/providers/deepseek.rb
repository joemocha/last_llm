# frozen_string_literal: true
require 'last_llm/providers/constants'

# Deepseek provider implementation
class Deepseek < LastLLM::Provider
      BASE_ENDPOINT = 'https://api.deepseek.com'

      def initialize(config)
        super(Constants::DEEPSEEK, config)
        @conn = connection(config[:base_url] || BASE_ENDPOINT)
      end

      def generate_text(prompt, options = {})
        messages = format_messages(prompt, options)

        response = @conn.post('/v1/chat/completions') do |req|
          req.body = {
            model: options[:model] || 'deepseek-chat',
            messages: messages,
            temperature: options[:temperature] || 0.7,
            max_tokens: options[:max_tokens],
            stream: false
          }.compact
        end

        result = parse_response(response)
        content = result.dig(:choices, 0, :message, :content)

        content.to_s
      rescue Faraday::Error => e
        handle_request_error(e)
      end

      def generate_object(prompt, schema, options = {})
        system_prompt = "You are a helpful assistant that responds with valid JSON."
        formatted_prompt = LastLLM::StructuredOutput.format_prompt(prompt, schema)

        messages = [
          { role: 'system', content: system_prompt },
          { role: 'user', content: formatted_prompt }
        ]

        response = @conn.post('/v1/chat/completions') do |req|
          req.body = {
            model: options[:model] || 'deepseek-chat',
            messages: messages,
            temperature: options[:temperature] || 0.2,
            stream: false
          }.compact
        end

        result = parse_response(response)
        content = result.dig(:choices, 0, :message, :content)

        begin
          JSON.parse(content, symbolize_names: true)
        rescue JSON::ParserError => e
          raise LastLLM::ApiError, "Invalid JSON response: #{e.message}"
        end
      rescue Faraday::Error => e
        handle_request_error(e)
      end

      private

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

      # Format a tool for Deepseek function calling
      # @param tool [LastLLM::Tool] The tool to format
      # @return [Hash] The tool in Deepseek format
      def self.format_tool(tool)
        {
          type: "function",
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
end

# Also define it in the LastLLM::Providers namespace for consistency
module LastLLM
  module Providers
    # Reference to the Deepseek class defined above
    Deepseek = ::Deepseek
  end
end
