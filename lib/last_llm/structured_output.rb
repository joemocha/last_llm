# frozen_string_literal: true
require 'json'

module LastLLM
  # Class for generating structured data from LLM providers
  class StructuredOutput
    # Initialize a new structured output generator
    # @param client [LastLLM::Client] The client to use for generation
    def initialize(client)
      @client = client
    end

    # Generate a structured object from a prompt
    # @param prompt [String] The prompt to generate the object from
    # @param schema [Dry::Schema::JSON] The schema to validate against
    # @param options [Hash] Generation options
    # @option options [String] :model The model to use
    # @option options [Float] :temperature (0.2) The temperature to use
    # @return [Hash] The generated object
    # @raise [ValidationError] If the generated object fails validation
    def generate(prompt, schema, options = {})
      # Format the prompt with schema information
      formatted_prompt = self.class.format_prompt(prompt, schema)

      # Set a lower temperature by default for structured data
      options = { temperature: 0.2 }.merge(options)

      # Generate the object using the provider
      result = @client.provider.generate_object(formatted_prompt, schema, options)

      # Validate the result against the schema
      validation = schema.call(result)

      if validation.success?
        result
      else
        raise ValidationError, "Generated object failed validation: #{validation.errors.to_h}"
      end
    end

    # Format a prompt with schema information
    # @param prompt [String] The original prompt
    # @param schema [Dry::Schema::JSON] The schema to include
    # @return [String] The formatted prompt
    def self.format_prompt(prompt, schema)
      schema_json = Schema.to_json_schema(schema)

      <<~PROMPT
        #{prompt}

        Respond with valid JSON that matches the following schema:

        #{schema_json}

        Ensure your response is a valid JSON object that strictly follows this schema.
      PROMPT
    end
  end
end
