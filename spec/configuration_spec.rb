# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LastLLM::Configuration do
  describe 'initialization' do
    it 'initializes with default values' do
      config = LastLLM::Configuration.new
      expect(config.default_provider).to eq(:openai)
      expect(config.default_model).to eq('gpt-3.5-turbo')
      expect(config.providers).to be_a(Hash)
    end

    it 'allows overriding defaults' do
      config = LastLLM::Configuration.new(
        default_provider: :anthropic,
        default_model: 'claude-2'
      )
      expect(config.default_provider).to eq(:anthropic)
      expect(config.default_model).to eq('claude-2')
    end
  end

  describe 'provider configuration' do
    it 'allows setting provider-specific configuration' do
      config = LastLLM::Configuration.new
      config.configure_provider(:openai, api_key: 'test-key', organization_id: 'test-org')

      expect(config.providers[:openai][:api_key]).to eq('test-key')
      expect(config.providers[:openai][:organization_id]).to eq('test-org')
    end

    it 'merges new provider configuration with existing' do
      config = LastLLM::Configuration.new
      config.configure_provider(:openai, api_key: 'test-key')
      config.configure_provider(:openai, organization_id: 'test-org')

      expect(config.providers[:openai][:api_key]).to eq('test-key')
      expect(config.providers[:openai][:organization_id]).to eq('test-org')
    end
  end

  describe 'validation' do
    it 'validates required configuration for a provider' do
      config = LastLLM::Configuration.new

      expect do
        config.validate_provider_config!(:openai)
      end.to raise_error(LastLLM::ConfigurationError, /api key is required/)

      config.configure_provider(:openai, api_key: 'test-key')
      expect { config.validate_provider_config!(:openai) }.not_to raise_error
    end
  end

  describe 'global settings' do
    it 'allows setting and retrieving global settings' do
      config = LastLLM::Configuration.new
      config.set_global(:timeout, 30)
      config.set_global(:max_retries, 3)

      expect(config.get_global(:timeout)).to eq(30)
      expect(config.get_global(:max_retries)).to eq(3)
    end
  end
end
