require 'spec_helper'

RSpec.describe LastLLM::Provider do
  # Create a concrete provider class for testing
  class ConcreteProviderForTest < LastLLM::Provider
    def initialize(config = {})
      super(:test, config)
    end

    def generate_text(prompt, options = {})
      "Test response for: #{prompt}"
    end

    def generate_object(prompt, schema, options = {})
      { name: "Test", age: 42 }
    end
  end

  let(:config) do
    {
      api_key: 'test-key',
      organization_id: 'test-org'
    }
  end

  let(:provider) { ConcreteProviderForTest.new(config) }

  describe 'initialization' do
    it 'initializes with a name and configuration' do
      expect(provider.name).to eq(:test)
      expect(provider.config).to eq(config)
    end

    it 'raises an error when instantiating the abstract class directly' do
      expect {
        LastLLM::Provider.new(:abstract, {})
      }.to raise_error(NotImplementedError)
    end
  end

  describe 'required method implementations' do
    context 'in abstract class' do
      let(:abstract_provider) do
        Class.new(LastLLM::Provider) do
          def initialize(config = {})
            super(:incomplete, { skip_validation: true })
          end
        end
      end

      let(:concrete_class) do
        Class.new(described_class) do
          def initialize
            super(:test, { skip_validation: true })
          end
        end
      end

      it 'requires #generate_text to be implemented' do
        provider = abstract_provider.new
        expect {
          provider.generate_text('Test')
        }.to raise_error(NotImplementedError)
      end

      it 'requires #generate_object to be implemented' do
        provider = abstract_provider.new
        schema = double('schema')
        expect {
          provider.generate_object('Test', schema)
        }.to raise_error(NotImplementedError)
      end
    end

    context 'in concrete implementation' do
      it 'implements #generate_text' do
        expect(provider.generate_text('Hello')).to eq('Test response for: Hello')
      end

      it 'implements #generate_object' do
        schema = double('schema')
        expect(provider.generate_object('Hello', schema)).to eq({ name: "Test", age: 42 })
      end
    end
  end

  describe 'authentication' do
    it 'validates required authentication configuration' do
      expect {
        ConcreteProviderForTest.new({})
      }.to raise_error(LastLLM::ConfigurationError, /API key is required/)
    end

    it 'accepts valid authentication configuration' do
      expect {
        ConcreteProviderForTest.new({ api_key: 'test-key' })
      }.not_to raise_error
    end
  end

  describe 'common provider utilities' do
    it 'provides access to common request/response handling methods' do
      expect(provider).to respond_to(:handle_request_error)
      expect(provider).to respond_to(:parse_response)
    end
  end
end
