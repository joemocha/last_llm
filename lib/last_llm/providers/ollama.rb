# frozen_string_literal: true

require 'last_llm/providers/constants'

# Ollama provider implementation
class Ollama < LastLLM::Provider
  BASE_ENDPOINT = 'http://172.17.0.1:11434'

  def initialize(config)
    super(Constants::OLLAMA, config)
    @conn = connection(config[:base_url] || BASE_ENDPOINT)
  end

  def generate_text(prompt, options = {})
    messages = format_messages(prompt, options)

    response = @conn.post('/v1/chat/completions') do |req|
      req.body = {
        model: options[:model] || 'llama3.2:latest',
        messages: messages,
        temperature: options[:temperature] || 0.7,
        top_p: options[:top_p] || 0.7,
        max_tokens: options[:max_tokens] || 24_576,
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
    system_prompt = 'You are a helpful assistant that responds with valid JSON.'
    formatted_prompt = LastLLM::StructuredOutput.format_prompt(prompt, schema)

    messages = [
      { role: 'system', content: system_prompt },
      { role: 'user', content: formatted_prompt }
    ]

    response = @conn.post('/v1/chat/completions') do |req|
      req.body = {
        model: options[:model] || 'llama3.2:latest',
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
end

# Also define it in the LastLLM::Providers namespace for consistency
module LastLLM
  module Providers
    # Reference to the Ollama class defined above
    Ollama = ::Ollama
  end
end
