# frozen_string_literal: true

require 'last_llm/providers/constants'

module LastLLM
  module Providers
    # Google Gemini provider implementation
    class GoogleGemini < LastLLM::Provider
      BASE_ENDPOINT = 'https://generativelanguage.googleapis.com'
      DEFAULT_MODEL = 'gemini-1.5-flash'

      def initialize(config)
        super(Constants::GOOGLE_GEMINI, config)
        @api_key = config[:api_key]
        @conn = connection(config[:base_url] || BASE_ENDPOINT)
      end

      def generate_text(prompt, options = {})
        make_request(prompt, options) do |response|
          extract_text_content(response)
        end
      end

      def generate_object(prompt, schema, options = {})
        options = options.merge(response_mime_type: 'application/json', response_schema: schema)
        make_request(prompt, options) do |response|
          parse_json_response(extract_text_content(response))
        end
      end

      private

      def make_request(prompt, options = {})
        model = options[:model] || @config[:model] || DEFAULT_MODEL
        contents = format_contents(prompt, options)

        response = @conn.post("/v1beta/models/#{model}:generateContent?key=#{@api_key}") do |req|
          req.body = build_request_body(contents, options)
        end

        handle_response(response) { |result| yield(result) }
      rescue Faraday::Error => e
        handle_gemini_error(e)
      end

      def build_request_body(contents, options)
        {
          contents: contents,
          generationConfig: {
            maxOutputTokens: options[:max_tokens],
            temperature: options[:temperature] || 0.3,
            topP: options[:top_p] || 0.95,
            topK: options[:top_k] || 40,
            responseMimeType: options[:response_mime_type],
            responseSchema: options[:response_schema]
          }.compact
        }.compact
      end

      def handle_response(response)
        if response.status != 200
          error = build_error(response)
          return handle_gemini_error(error)
        end

        result = parse_response(response)
        yield(result)
      end

      def build_error(response)
        error = Faraday::Error.new("HTTP #{response.status}")
        error.instance_variable_set(:@response, {
          status: response.status,
          body: response.body.to_json
        })
        error
      end

      def extract_text_content(response)
        content = response.dig(:candidates, 0, :content, :parts, 0, :text)
        content.to_s
      end

      def parse_json_response(content)
        JSON.parse(content, symbolize_names: true)
      rescue JSON::ParserError => e
        raise LastLLM::ApiError, "Invalid JSON response: #{e.message}"
      end

      def connection(endpoint)
        Faraday.new(url: endpoint) do |faraday|
          faraday.request :json
          faraday.response :json, content_type: /\bjson$/
          faraday.adapter Faraday.default_adapter
        end
      end

      def format_contents(prompt, options)
        if prompt.is_a?(Array)
          prompt.map { |m| { role: m[:role], parts: [{ text: m[:content] }] } }
        elsif options[:system_prompt]
          [
            { role: 'user', parts: [{ text: options[:system_prompt] }] },
            { role: 'user', parts: [{ text: prompt.to_s }] }
          ]
        else
          [{ role: 'user', parts: [{ text: prompt.to_s }] }]
        end
      end

      def self.format_tool(tool)
        {
          name: tool.name,
          description: tool.description,
          parameters: tool.parameters
        }
      end

      def self.execute_tool(tool, response)
        function_call = response.dig(:candidates, 0, :content, :parts, 0, :functionCall)
        return nil unless function_call && function_call[:name] == tool.name

        tool.call(function_call[:args])
      end

      def handle_gemini_error(error)
        status = error.response&.dig(:status)
        message = parse_error_message(error)

        raise LastLLM::ApiError.new(message, status)
      end

      def parse_error_message(error)
        return "API request failed: #{error.message}" unless error.response&.dig(:body)

        body = parse_error_body(error.response[:body])
        format_error_message(body)
      rescue JSON::ParserError
        "API request failed: #{error.message}"
      end

      def parse_error_body(body)
        return {} unless body.is_a?(String) && !body.empty?
        JSON.parse(body)
      end

      def format_error_message(body)
        if body.is_a?(Array) && body[0]&.dig('error')
          error_obj = body[0]['error']
          "API error: #{error_obj['message'] || error_obj}"
        elsif body['error']
          format_detailed_error(body['error'])
        else
          'Unknown API error'
        end
      end

      def format_detailed_error(error)
        message = error['message']
        code = error['code']
        status = error['status']

        case [code, status]
        when [401, 'UNAUTHENTICATED']
          'Authentication failed: Invalid API key or credentials. Please check your Google API key.'
        when [400]
          message.include?('API key not valid') ?
            'Authentication failed: Invalid API key format or credentials. Please check your Google API key.' :
            "API error (#{code}): #{message}"
        else
          "API error (#{code}): #{message}"
        end
      end
    end
  end
end
