# frozen_string_literal: true

module LastLLM
  class Completion
    def initialize(client)
      @client = client
    end

    # Generate text completion in a single response
    # @param prompt [String] The input text to complete
    # @param options [Hash] Options to control the completion
    # @return [String] The generated text
    def generate(prompt, options = {})
      @client.provider.generate_text(prompt, options)
    end

    # Stream text completion in chunks
    # @param prompt [String] The input text to complete
    # @param options [Hash] Options to control the completion
    # @yield [String] Each chunk of generated text
    def stream(prompt, options = {})
      raise ArgumentError, "Block required" unless block_given?
      @client.provider.stream_text(prompt, options) { |chunk| yield chunk }
    end
  end
end
