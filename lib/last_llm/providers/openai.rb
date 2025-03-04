# frozen_string_literal: true

require 'last_llm/providers/constants'

# OpenAI provider implementation
class OpenAI < LastLLM::Provider
  BASE_ENDPOINT = 'https://api.openai.com'

  def initialize(config)
    super(Constants::OPENAI, config)
    # Using the base URL without trailing /v1 as the connection URL
    # since we'll include /v1 in each request path
    @conn = connection(config[:base_url] || BASE_ENDPOINT)
  end

  def generate_text(prompt, options = {})
    messages = format_messages(prompt, options)

    response = @conn.post('/v1/chat/completions') do |req|
      req.body = {
        model: options[:model] || 'gpt-3.5-turbo',
        messages: messages,
        temperature: options[:temperature] || 0.7,
        top_p: options[:top_p] || 0.7,
        max_tokens: options[:max_tokens] || 24576,
        stream: false
      }.compact
    end

    result = parse_response(response)
    # Changed to handle both new and old API response formats
    content = result.dig(:choices, 0, :message, :content)

    content.to_s
  rescue Faraday::Error => e
    handle_request_error(e)
  end

  def generate_object(prompt, schema, options = {})
    # Create a system message that instructs the model to return JSON
    system_prompt = "You are a helpful assistant that responds with valid JSON."

    # Format the prompt with schema information using the Schema class
    formatted_prompt = LastLLM::StructuredOutput.format_prompt(prompt, schema)

    messages = [
      { role: 'system', content: system_prompt },
      { role: 'user', content: formatted_prompt }
    ]

    response = @conn.post('/v1/chat/completions') do |req|
      req.body = {
        model: options[:model] || 'gpt-4o-mini',
        messages: messages,
        temperature: options[:temperature] || 0.2,
        response_format: { type: "json_object" },
        stream: false
      }.compact
    end

    result = parse_response(response)
    content = result.dig(:choices, 0, :message, :content)

    # Parse the JSON content
    begin
      json_data = JSON.parse(content, symbolize_names: true)
      if json_data.key?(:'$schema') && json_data.key?(:properties)
        json_data[:properties]
      else
        json_data
      end
    rescue JSON::ParserError => e
      raise LastLLM::ApiError, "Invalid JSON response: #{e.message}"
    end
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

    unless embeddings.is_a?(Array)
      raise LastLLM::ApiError.new("Invalid embeddings response format", nil)
    end

    embeddings
  rescue Faraday::Error => e
    handle_request_error(e)
  end

  private

  def format_messages(prompt, options)
    if prompt.is_a?(Array) && prompt.all? { |m| m.is_a?(Hash) && m[:role] && m[:content] }
      # Already in the correct format
      prompt
    elsif options[:system_prompt]
      # Use system prompt if provided
      [
        { role: 'system', content: options[:system_prompt] },
        { role: 'user', content: prompt.to_s }
      ]
    else
      # Simple user message
      [{ role: 'user', content: prompt.to_s }]
    end
  end

  def parse_response(response)
    parsed = if response.body.is_a?(Hash)
               response.body
             else
               JSON.parse(response.body)
             end

    if parsed.nil? || (!parsed.is_a?(Hash) && !parsed.respond_to?(:to_h))
      raise LastLLM::ApiError.new("Invalid response format from OpenAI", nil)
    end

    # Use the new method
    parsed = deep_symbolize_keys(parsed) if parsed.is_a?(Hash)

    if parsed[:error]
      raise LastLLM::ApiError.new(parsed[:error][:message], parsed[:error][:code])
    end

    parsed
  rescue JSON::ParserError => e
    raise LastLLM::ApiError.new("Failed to parse OpenAI response: #{e.message}", nil)
  end

  def handle_request_error(error)
    message = "OpenAI API request failed: #{error.message}"
    status = nil

    if error.respond_to?(:response) && error.response
      status = error.response.status if error.response.respond_to?(:status)
    end

    raise LastLLM::ApiError.new(message, status)
  end

  # Format a tool for OpenAI function calling
  # @param tool [LastLLM::Tool] The tool to format
  # @return [Hash] The tool in OpenAI format
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

  # Execute a tool from an OpenAI response
  # @param tool [LastLLM::Tool] The tool to execute
  # @param response [Hash] The OpenAI response containing tool call information
  # @return [Hash, nil] The result of the function call or nil if the tool wasn't called
  def self.execute_tool(tool, response)
    tool_call = response[:tool_calls]&.first
    return nil unless tool_call && tool_call[:function][:name] == tool.name

    arguments = JSON.parse(tool_call[:function][:arguments], symbolize_names: true)
    tool.call(arguments)
  end
end
