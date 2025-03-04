# frozen_string_literal: true
require 'last_llm/providers/constants'

# Anthropic provider implementation
class Anthropic < LastLLM::Provider
      BASE_ENDPOINT = 'https://api.anthropic.com'

      def initialize(config)
        super(:anthropic, config)
        @conn = connection(config[:base_url] || BASE_ENDPOINT)
      end

      def generate_text(prompt, options = {})
        messages = format_messages(prompt, options)

        response = @conn.post('/v1/messages') do |req|
          req.body = {
            model: options[:model] || 'claude-3-5-haiku-latest',
            messages: messages,
            temperature: options[:temperature] || 0.7,
            max_tokens: options[:max_tokens] || 1000,
            stream: false
          }.compact
        end

        result = parse_response(response)
        content = result.dig(:content, 0, :text)

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

        response = @conn.post('/v1/messages') do |req|
          req.body = {
            model: options[:model] || 'claude-3-5-haiku-latest',
            messages: messages,
            temperature: options[:temperature] || 0.2,
            stream: false
          }.compact
        end

        result = parse_response(response)
        content = result.dig(:content, 0, :text)

        begin
          JSON.parse(content, symbolize_names: true)
        rescue JSON::ParserError => e
          raise ApiError, "Invalid JSON response: #{e.message}"
        end
      rescue Faraday::Error => e
        handle_request_error(e)
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

      def setup_authorization(conn)
        conn.headers['x-api-key'] = @config[:api_key]
        conn.headers['anthropic-version'] = '2023-06-01'
      end
end

# Also define it in the LastLLM::Providers namespace for consistency
module LastLLM
  module Providers
    # Reference to the Anthropic class defined above
    Anthropic = ::Anthropic
  end
end
