# frozen_string_literal: true

require 'spec_helper'
require 'last_llm/providers/test_provider'

RSpec.describe LastLLM::Client do
  let(:config) do
    LastLLM::Configuration.new(test_mode: false).tap do |c|
      c.configure_provider(:openai, api_key: 'test-key')
      c.configure_provider(:test, {}) # Configure the test provider
    end
  end

  let(:client) { LastLLM::Client.new(config) }
  let(:test_provider) { LastLLM::Providers::TestProvider.new }

  def setup_client_with_test_provider
    client = LastLLM::Client.new(config)
    client.instance_variable_set(:@provider, test_provider)
    client
  end

  describe 'initialization' do
    it 'initializes with a configuration' do
      expect(client.configuration).to eq(config)
    end

    it 'initializes with default configuration when none provided' do
      client = LastLLM::Client.new
      expect(client.configuration).to be_a(LastLLM::Configuration)
    end

    it 'raises an error when no API key is provided in non-test mode' do
      empty_config = LastLLM::Configuration.new(test_mode: false)
      expect do
        LastLLM::Client.new(empty_config)
      end.to raise_error(LastLLM::ConfigurationError, /api key is required/)
    end
  end

  describe 'provider selection' do
    it 'selects the default provider' do
      expect(client.provider).to be_a(LastLLM::Provider)
    end

    it 'allows specifying a different provider' do
      config.configure_provider(:anthropic, api_key: 'anthropic-key')
      client = LastLLM::Client.new(config, provider: :anthropic)
      expect(client.provider).to be_a(LastLLM::Provider)
      expect(client.provider.name).to eq(:anthropic)
    end

    it 'raises an error for unconfigured providers' do
      expect do
        LastLLM::Client.new(config, provider: :unconfigured)
      end.to raise_error(LastLLM::ConfigurationError)
    end

    it 'raises an error when provider has no API key in non-test mode' do
      config = LastLLM::Configuration.new(test_mode: false)
      config.configure_provider(:openai, {}) # Empty config with no API key

      expect do
        LastLLM::Client.new(config)
      end.to raise_error(LastLLM::ConfigurationError, /api key is required/)
    end
  end

  describe '#generate_text' do
    it 'generates text from a prompt' do
      client = setup_client_with_test_provider
      test_provider.text_response = 'Generated text response'

      result = client.generate_text('Test prompt')
      expect(result).to eq('Generated text response')
    end

    it 'passes options to the provider' do
      client = setup_client_with_test_provider
      options = { model: 'gpt-4', temperature: 0.7 }

      expect do
        client.generate_text('Test prompt', options)
      end.not_to raise_error
    end
  end

  describe '#generate_object' do
    let(:schema) do
      Dry::Schema.JSON do
        required(:name).filled(:string)
        required(:age).filled(:integer)
      end
    end

    it 'generates a structured object from a prompt' do
      client = setup_client_with_test_provider
      object_data = { name: 'John', age: 30 }
      test_provider.object_response = object_data

      result = client.generate_object('Generate a person', schema)
      expect(result).to eq(object_data)
    end

    it 'passes options to the provider' do
      client = setup_client_with_test_provider
      test_provider.object_response = { name: 'John', age: 30 }
      options = { model: 'gpt-4', temperature: 0.7 }

      expect do
        client.generate_object('Generate a person', schema, options)
      end.not_to raise_error
    end

    it 'raises an error when validation fails' do
      client = setup_client_with_test_provider
      invalid_data = { name: 'John', age: 'thirty' }
      test_provider.object_response = invalid_data

      expect do
        client.generate_object('Generate a person', schema)
      end.to raise_error(LastLLM::ValidationError)
    end
  end

  context 'with test mode enabled' do
    let(:test_config) do
      LastLLM::Configuration.new(test_mode: true)
    end

    it 'allows initialization without API keys' do
      expect do
        LastLLM::Client.new(test_config)
      end.not_to raise_error
    end

    it 'allows changing providers without API keys' do
      client = LastLLM::Client.new(test_config)
      expect do
        client.instance_variable_set(:@provider, client.send(:create_provider, :anthropic))
      end.not_to raise_error
    end
  end
end
