# frozen_string_literal: true

require 'last_llm/providers/constants'

module LastLLM
  module Providers
    # Anthropic provider implementation
    class Anthropic < LastLLM::Provider
      BASE_ENDPOINT = 'https://api.anthropic.com'

      def initialize(config)
        super(:anthropic, config)
        @conn = connection(config[:base_url] || BASE_ENDPOINT)
      end

      def generate_text(prompt, options = {})
        options = options.dup
        messages = format_messages(prompt, options)

        body = {
          model: options[:model] || 'claude-3-5-haiku-latest',
          messages: messages,
          max_tokens: options[:max_tokens] || 8192,
          temperature: options[:temperature] || 0.2,
          top_p: options[:top_p] || 0.8,
          stream: false
        }

        # Add system parameter if system prompt is provided
        body[:system] = options[:system_prompt] if options[:system_prompt]

        response = @conn.post('/v1/messages') do |req|
          req.body = body.compact
        end

        result = parse_response(response)
        content = result.dig(:content, 0, :text)

        content.to_s
      rescue Faraday::Error => e
        handle_request_error(e)
      end

      def generate_object(prompt, schema, options = {})
        options = options.dup
        system_prompt = "You are a helpful assistant that responds with valid JSON."
        formatted_prompt = LastLLM::StructuredOutput.format_prompt(prompt, schema)

        options[:system_prompt] = system_prompt

        body = {
          model: options[:model] || 'claude-3-5-haiku-latest',
          messages: [{ role: 'user', content: formatted_prompt }],
          max_tokens: options[:max_tokens] || 8192,
          system: options[:system_prompt],
          temperature: options[:temperature] || 0.2,
          top_p: options[:top_p] || 0.8,
          stream: false
        }.compact

        response = @conn.post('/v1/messages') do |req|
          req.body = body
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

      def setup_authorization(conn)
        conn.headers['x-api-key'] = @config[:api_key]
        conn.headers['anthropic-version'] = '2023-06-01'
      end
    end
  end
end
