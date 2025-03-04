# frozen_string_literal: true

require 'last_llm/providers/constants'

# Google Gemini provider implementation
class GoogleGemini < LastLLM::Provider
  BASE_ENDPOINT = 'https://generativelanguage.googleapis.com'

  def initialize(config)
    super(Constants::GOOGLE_GEMINI, config)
    @api_key = config[:api_key]
    @conn = connection(config[:base_url] || BASE_ENDPOINT)
  end

  def generate_text(prompt, options = {})
    model = options[:model] || 'gemini-1.5-flash'
    contents = format_contents(prompt, options)

    response = @conn.post("/v1beta/models/#{model}:generateContent?key=#{@api_key}") do |req|
      req.body = {
        contents: contents,
        generationConfig: {
          maxOutputTokens: options[:max_tokens],
          temperature: options[:temperature] || 0.3,
          topP: options[:top_p] || 0.95,
          topK: options[:top_k] || 40
        }.compact
      }.compact
    end

    # Check for error responses even when they don't raise exceptions
    if response.status != 200
      error = Faraday::Error.new("HTTP #{response.status}")
      error.instance_variable_set(:@response, { status: response.status, body: response.body.to_json })
      return handle_gemini_error(error)
    end

    result = parse_response(response)
    content = result.dig(:candidates, 0, :content, :parts, 0, :text)

    content.to_s
  rescue Faraday::Error => e
    handle_gemini_error(e)
  end

  def generate_object(prompt, schema, options = {})
    model = options[:model] || 'gemini-1.5-flash'
    contents = format_contents(prompt, options)

    response = @conn.post("/v1beta/models/#{model}:generateContent?key=#{@api_key}") do |req|
      req.body = {
        contents: contents,
        generationConfig: {
          temperature: options[:temperature] || 0.7,
          maxOutputTokens: options[:max_tokens],
          topP: options[:top_p] || 0.95,
          topK: options[:top_k] || 40,
          responseMimeType: "application/json",
          responseSchema: schema
        }.compact
      }.compact
    end

    # Check for error responses even when they don't raise exceptions
    if response.status != 200
      error = Faraday::Error.new("HTTP #{response.status}")
      error.instance_variable_set(:@response, { status: response.status, body: response.body.to_json })
      return handle_gemini_error(error)
    end

    result = parse_response(response)
    content = result.dig(:candidates, 0, :content, :parts, 0, :text)

    begin
      JSON.parse(content, symbolize_names: true)
    rescue JSON::ParserError => e
      raise LastLLM::ApiError, "Invalid JSON response: #{e.message}"
    end
  rescue Faraday::Error => e
    handle_gemini_error(e)
  end

  private

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

  # Format a tool for Google Gemini function calling
  # @param tool [LastLLM::Tool] The tool to format
  # @return [Hash] The tool in Google Gemini format
  def self.format_tool(tool)
    {
      name: tool.name,
      description: tool.description,
      parameters: tool.parameters
    }
  end

  # Execute a tool from a Google Gemini response
  # @param tool [LastLLM::Tool] The tool to execute
  # @param response [Hash] The Google Gemini response containing function call information
  # @return [Hash, nil] The result of the function call or nil if the tool wasn't called
  def self.execute_tool(tool, response)
    function_call = response.dig(:candidates, 0, :content, :parts, 0, :functionCall)
    return nil unless function_call && function_call[:name] == tool.name

    arguments = function_call[:args]
    tool.call(arguments)
  end

  # Custom error handler for Gemini API responses
  def handle_gemini_error(error)
    status = nil
    message = "API request failed: #{error.message}"

    if error.respond_to?(:response) && error.response.is_a?(Hash)
      status = error.response[:status]
      body = error.response[:body]

      if body.is_a?(String) && !body.empty?
        begin
          parsed_body = JSON.parse(body)
          # Handle array response format
          if parsed_body.is_a?(Array) && parsed_body[0] && parsed_body[0]["error"]
            error_obj = parsed_body[0]["error"]
            message = "API error: #{error_obj["message"] || error_obj}"
          # Handle object response format
          elsif parsed_body["error"]
            error_message = parsed_body["error"]["message"] || parsed_body["error"]
            error_code = parsed_body["error"]["code"]
            error_status = parsed_body["error"]["status"]
            message = "API error (#{error_code}): #{error_message}"
            # Handle authentication errors
            if error_code == 401 && error_status == "UNAUTHENTICATED"
              message = "Authentication failed: Invalid API key or credentials. Please check your Google API key."
            elsif error_code == 400 && error_message.include?("API key not valid")
              message = "Authentication failed: Invalid API key format or credentials. Please check your Google API key."
            end
          end
        rescue JSON::ParserError
          # Use default message if we can't parse the body
        end
      end
    end

    raise LastLLM::ApiError.new(message, status)
  end
end

# Also define it in the LastLLM::Providers namespace for consistency
module LastLLM
  module Providers
    # Reference to the GoogleGemini class defined above
    GoogleGemini = ::GoogleGemini
  end
end
