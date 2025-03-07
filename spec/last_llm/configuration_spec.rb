require 'rspec'
require 'last_llm/configuration'
require 'last_llm/providers/constants'

RSpec.describe LastLLM::Configuration do
  let(:config) { LastLLM::Configuration.new }

  describe '#set_provider_config and #get_provider_config' do
    it 'sets and gets a provider configuration value' do
      config.set_provider_config(:openai, :api_key, 'my_key')
      expect(config.get_provider_config(:openai, :api_key)).to eq('my_key')
    end

    it 'returns full provider configuration when key is nil' do
      config.set_provider_config('openai', 'api_key', 'my_key')
      expect(config.get_provider_config(:openai)).to eq({ api_key: 'my_key' })
    end
  end

  describe '#set_global and #get_global' do
    it 'sets and gets a global configuration value' do
      config.set_global(:timeout, 120)
      expect(config.get_global(:timeout)).to eq(120)
    end
  end

  describe '#validate_provider_config!' do
    context 'when required field is missing' do
      it 'raises a ConfigurationError for provider openai' do
        expect {
          config.validate_provider_config!(LastLLM::Providers::Constants::OPENAI)
        }.to raise_error(LastLLM::ConfigurationError, /api key is required/)
      end
    end

    context 'when required field is set' do
      it 'does not raise an error for provider openai' do
        config.set_provider_config(:openai, :api_key, 'my_key')
        expect {
          config.validate_provider_config!(LastLLM::Providers::Constants::OPENAI)
        }.not_to raise_error
      end
    end

    context 'when in test mode' do
      it 'skips validation' do
        test_config = LastLLM::Configuration.new(test_mode: true)
        expect {
          test_config.validate_provider_config!(LastLLM::Providers::Constants::OPENAI)
        }.not_to raise_error
      end
    end
  end
end
