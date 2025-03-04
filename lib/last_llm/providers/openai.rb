# frozen_string_literal: true

require 'last_llm/providers/constants'

# OpenAI provider implementation
class OpenAI < LastLLM::Provider
  BASE_ENDPOINT = 'https://api.openai.com'

  def initialize(config)
    super(Constants::OPENAI, config)
    @conn = connection(config[:base_url] || BASE_ENDPOINT)
  end

  def generate_text(prompt, options = {})
    request_body = build_completion_request(prompt, options)
    response = make_completion_request(request_body)
    extract_content(response)
  rescue Faraday::Error => e
    handle_request_error(e)
  end

  def generate_object(prompt, schema, options = {})
    request_body = build_json_request(prompt, schema, options)
    response = make_completion_request(request_body)
    parse_json_response(response)
  rescue Faraday::Error => e
    handle_request_error(e)
  end

  # Generate embeddings from text
  # @param text [String] The text to generate embeddings for
  # @param options [Hash] Options for the embedding generation
  # @return [Array<Float>] The embedding vector as an array of floats
  def embeddings(text, options = {})
    # Ensure text is a string
    text_str = text.to_s

    response = @conn.post('/v1/embeddings') do |req|
      req.body = {
        model: options[:model] || 'text-embedding-ada-002',
        input: text_str,
        encoding_format: options[:encoding_format] || 'float'
      }.compact
    end

    result = parse_response(response)

    # Extract embeddings from response
    embeddings = result.dig(:data, 0, :embedding)

    raise LastLLM::ApiError.new('Invalid embeddings response format', nil) unless embeddings.is_a?(Array)

    embeddings
  rescue Faraday::Error => e
    handle_request_error(e)
  end

  private

  def build_completion_request(prompt, options)
    {
      model: options[:model] || 'gpt-3.5-turbo',
      messages: format_messages(prompt, options),
      temperature: options[:temperature] || 0.7,
      top_p: options[:top_p] || 0.7,
      max_tokens: options[:max_tokens] || 24_576,
      stream: false
    }.compact
  end

  def build_json_request(prompt, schema, options)
    {
      model: options[:model] || 'gpt-4',
      messages: format_json_messages(prompt, schema),
      temperature: options[:temperature] || 0.2,
      response_format: { type: 'json_object' },
      stream: false
    }.compact
  end

  def make_completion_request(body)
    @conn.post('/v1/chat/completions') do |req|
      req.body = body
    end
  end

  def format_json_messages(prompt, schema)
    system_prompt = 'You are a helpful assistant that responds with valid JSON.'
    formatted_prompt = LastLLM::StructuredOutput.format_prompt(prompt, schema)

    [
      { role: 'system', content: system_prompt },
      { role: 'user', content: formatted_prompt }
    ]
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

  def extract_content(response)
    result = parse_response(response)
    result.dig(:choices, 0, :message, :content).to_s
  end

  def parse_json_response(response)
    content = extract_content(response)
    parsed_json = JSON.parse(content, symbolize_names: true)

    if parsed_json.key?(:$schema) && parsed_json.key?(:properties)
      parsed_json[:properties]
    else
      parsed_json
    end
  rescue JSON::ParserError => e
    raise LastLLM::ApiError, "Invalid JSON response: #{e.message}"
  end

  def parse_response(response)
    parsed = if response.body.is_a?(Hash)
               response.body
             else
               JSON.parse(response.body)
             end

    validate_response(parsed)
    deep_symbolize_keys(parsed)
  rescue JSON::ParserError => e
    raise LastLLM::ApiError.new("Failed to parse OpenAI response: #{e.message}", nil)
  end

  def validate_response(parsed)
    if parsed.nil? || (!parsed.is_a?(Hash) && !parsed.respond_to?(:to_h))
      raise LastLLM::ApiError.new('Invalid response format from OpenAI', nil)
    end

    raise LastLLM::ApiError.new(parsed[:error][:message], parsed[:error][:code]) if parsed[:error]
  end

  def handle_request_error(error)
    message = "OpenAI API request failed: #{error.message}"
    status = error.respond_to?(:response) && error.response.respond_to?(:status) ? error.response.status : nil
    raise LastLLM::ApiError.new(message, status)
  end

  # Format a tool for OpenAI function calling
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

  # Execute a tool from an OpenAI response
  def self.execute_tool(tool, response)
    tool_call = response[:tool_calls]&.first
    return nil unless tool_call && tool_call[:function][:name] == tool.name

    arguments = JSON.parse(tool_call[:function][:arguments], symbolize_names: true)
    tool.call(arguments)
  end
end

# Also define it in the LastLLM::Providers namespace for consistency
module LastLLM
  module Providers
    OpenAI = ::OpenAI
  end
end
