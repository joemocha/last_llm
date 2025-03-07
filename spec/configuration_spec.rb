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
    let(:config) { LastLLM::Configuration.new }

    context 'with OpenAI provider' do
      it 'validates required api_key' do
        expect do
          config.validate_provider_config!(:openai)
        end.to raise_error(LastLLM::ConfigurationError, /api key is required/)

        config.configure_provider(:openai, api_key: 'test-key')
        expect { config.validate_provider_config!(:openai) }.not_to raise_error
      end
    end

    context 'with Anthropic provider' do
      it 'validates required api_key' do
        expect do
          config.validate_provider_config!(:anthropic)
        end.to raise_error(LastLLM::ConfigurationError, /api key is required/)

        config.configure_provider(:anthropic, api_key: 'test-key')
        expect { config.validate_provider_config!(:anthropic) }.not_to raise_error
      end
    end

    context 'with Google Gemini provider' do
      it 'validates required api_key' do
        expect do
          config.validate_provider_config!(:google_gemini)
        end.to raise_error(LastLLM::ConfigurationError, /api key is required/)

        config.configure_provider(:google_gemini, api_key: 'test-key')
        expect { config.validate_provider_config!(:google_gemini) }.not_to raise_error
      end
    end

    context 'with Deepseek provider' do
      it 'validates required api_key' do
        expect do
          config.validate_provider_config!(:deepseek)
        end.to raise_error(LastLLM::ConfigurationError, /api key is required/)

        config.configure_provider(:deepseek, api_key: 'test-key')
        expect { config.validate_provider_config!(:deepseek) }.not_to raise_error
      end
    end

    context 'with Ollama provider' do
      it 'validates host when api_key is not provided' do
        expect do
          config.validate_provider_config!(:ollama)
        end.to raise_error(LastLLM::ConfigurationError, /Ollama host is required when no API key is provided/)

        config.configure_provider(:ollama, host: 'http://localhost:11434')
        expect { config.validate_provider_config!(:ollama) }.not_to raise_error
      end

      it 'allows api_key without host' do
        config.configure_provider(:ollama, api_key: 'test-key')
        expect { config.validate_provider_config!(:ollama) }.not_to raise_error
      end
    end

    context 'with unknown provider' do
      it 'raises error for unknown provider' do
        expect do
          config.validate_provider_config!(:unknown)
        end.to raise_error(LastLLM::ConfigurationError, /Unknown provider: unknown/)
      end
    end

    context 'in test mode' do
      let(:test_config) { LastLLM::Configuration.new(test_mode: true) }

      it 'skips validation for all providers' do
        providers = [:openai, :anthropic, :google_gemini, :deepseek, :ollama]

        providers.each do |provider|
          expect { test_config.validate_provider_config!(provider) }.not_to raise_error
        end
      end
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

  describe 'logging configuration' do
    let(:config) { LastLLM::Configuration.new }
    let(:custom_logger) { Logger.new(StringIO.new) }

    it 'allows setting and getting logger' do
      config.logger = custom_logger
      expect(config.logger).to eq(custom_logger)
    end

    it 'defaults to nil logger' do
      expect(config.logger).to be_nil
    end

    it 'allows setting and getting log level' do
      config.log_level = :debug
      expect(config.log_level).to eq(:debug)
    end

    it 'defaults to :info log level' do
      expect(config.log_level).to eq(:info)
    end

    it 'validates log level' do
      expect { config.log_level = :invalid }.to raise_error(LastLLM::ConfigurationError, /Invalid log level/)
      expect { config.log_level = :debug }.not_to raise_error
      expect { config.log_level = :info }.not_to raise_error
      expect { config.log_level = :warn }.not_to raise_error
      expect { config.log_level = :error }.not_to raise_error
      expect { config.log_level = :fatal }.not_to raise_error
    end
  end
end
