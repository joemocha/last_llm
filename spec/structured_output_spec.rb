# frozen_string_literal: true

require 'spec_helper'
require 'dry-schema'

RSpec.describe LastLLM::StructuredOutput do
  let(:schema) do
    Dry::Schema.JSON do
      required(:name).filled(:string)
      required(:age).filled(:integer)
      optional(:email).maybe(:string)
    end
  end

  let(:client) do
    config = LastLLM::Configuration.new(test_mode: true)
    LastLLM::Client.new(config, provider: :test)
  end

  let(:test_provider) do
    client.provider
  end

  describe '.format_prompt' do
    it 'formats a prompt with schema information' do
      prompt = 'Generate information about a person'

      # Add a json_schema method to the schema for testing
      def schema.json_schema
        {
          type: 'object',
          properties: {
            'name' => { 'type' => 'string' },
            'age' => { 'type' => 'integer' }
          },
          required: %w[name age]
        }
      end

      formatted = LastLLM::StructuredOutput.format_prompt(prompt, schema)

      expect(formatted).to include(prompt)
      expect(formatted).to include('JSON')
      expect(formatted).to include('schema')
      expect(formatted).to include('name')
      expect(formatted).to include('age')
    end
  end

  describe '#generate' do
    it 'generates a structured object from a prompt', :vcr do
      structured_output = LastLLM::StructuredOutput.new(client)

      # Set up the test provider to return a valid response
      test_provider.object_response = { name: 'John Doe', age: 30 }

      result = structured_output.generate('Generate a person', schema)

      expect(result).to be_a(Hash)
      expect(result[:name]).to eq('John Doe')
      expect(result[:age]).to eq(30)
    end

    it 'raises a validation error when the response is invalid' do
      structured_output = LastLLM::StructuredOutput.new(client)

      # Set up the test provider to return an invalid response
      test_provider.object_response = { name: 'John Doe', age: 'thirty' }

      expect do
        structured_output.generate('Generate a person', schema)
      end.to raise_error(LastLLM::ValidationError)
    end

    it 'passes options to the provider' do
      structured_output = LastLLM::StructuredOutput.new(client)

      # Set up the test provider to return a valid response
      test_provider.object_response = { name: 'John Doe', age: 30 }

      # Spy on the provider's generate_object method
      allow(test_provider).to receive(:generate_object).and_call_original

      options = { model: 'gpt-4', temperature: 0.2 }
      structured_output.generate('Generate a person', schema, options)

      expect(test_provider).to have_received(:generate_object).with(
        anything, schema, hash_including(options)
      )
    end
  end
end
