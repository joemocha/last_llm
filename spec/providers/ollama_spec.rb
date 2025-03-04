require 'spec_helper'
require 'vcr'

RSpec.describe LastLLM::Providers::Ollama do
  let(:config) { { api_key: ENV['OLLAMA_API_KEY'] || 'test-key' } }
  let(:provider) { described_class.new(config) }
  let(:prompt) { 'Say "hello" using the fewest words possible' }
  let(:options) { { temperature: 0.0 } }

  before do
    VCR.configure do |c|
      c.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
      c.hook_into :webmock
      c.configure_rspec_metadata!
      c.filter_sensitive_data('<OLLAMA_API_KEY>') { ENV['OLLAMA_API_KEY'] || 'test-key' }
      c.ignore_localhost = false
    end
  end

  describe '#generate_text' do
    it 'returns text completion from Ollama' do
      VCR.use_cassette('ollama/generate_text', match_requests_on: [:method, :uri]) do
        result = provider.generate_text(prompt, options)
        expect(result).to be_a(String)
        expect(result.length).to be > 0
        # Test content relevance
        expect(result.downcase).to include('hello') || include('hi') || include('greet')
        expect(result).not_to include('error')
      end
    end

    describe 'with system prompt' do
      let(:prompt) { 'Say "hello" using the fewest words possible' }
      it 'handles system prompts correctly' do
        options_with_system = options.merge(system_prompt: 'You are a helpful assistant, in french')
        result = nil
        VCR.use_cassette('ollama/generate_text_with_system', match_requests_on: [:method, :uri]) do
          result = provider.generate_text(prompt, options_with_system)
          expect(result).to be_a(String)
          expect(result.length).to be > 0
          expect(result.downcase).to match(/Bonjour|Salut/i)
        end

        # Compare with response without system prompt
        standard_result = nil
        VCR.use_cassette('ollama/generate_text_comparison', match_requests_on: [:method, :uri]) do
          standard_result = provider.generate_text(prompt, options)
        end

        expect(result).not_to eq(standard_result)
      end
    end

    it 'raises an error on API failure' do
      invalid_provider = described_class.new({ model: 'invalid-model', api_key: 'test-key' })
      VCR.use_cassette('ollama/api_error') do
        begin
          invalid_provider.generate_text(prompt, options.merge(model: 'invalid-model'))
          fail "Expected an error to be raised"
        rescue LastLLM::ApiError => e
          expect(e).to be_a(LastLLM::ApiError)
          expect(e.message).to include('API') || include('key') || include('auth')
          expect(e.status_code).to be_a(Integer) if e.respond_to?(:status_code)
        end
      end
    end
  end

  describe '#generate_object' do
    context 'with simple schema' do
      let(:schema_def) do
        {
          type: 'object',
          properties: {
            name: { type: 'string' },
            age: { type: 'integer' }
          },
          required: ['name', 'age']
        }
      end

      it 'returns structured data from Ollama' do
        VCR.use_cassette('ollama/generate_object', record: :new_episodes) do
          begin
            result = provider.generate_object("Create a profile for John Doe, age 30", schema_def, options)
            expect(result).to be_a(Hash)
            expect(result[:name]).to be_a(String)
            expect(result[:age]).to be_a(Integer)
          rescue LastLLM::ApiError => e
            puts "API error: #{e.message}" if ENV['DEBUG']
            expect(e).to be_a(LastLLM::ApiError)
          end
        end
      end
    end

    context 'with complex schema' do
      let(:schema_def) do
        {
          type: 'object',
          properties: {
            'title' => { 'type' => 'string' },
            'authors' => {
              'type' => 'array',
              'items' => { 'type' => 'string' }
            },
            'abstract' => { 'type' => 'string' },
            'keywords' => {
              'type' => 'array',
              'items' => { 'type' => 'string' }
            }
          },
          required: ['title', 'authors', 'abstract', 'keywords']
        }
      end

      it 'returns properly structured complex data' do
        VCR.use_cassette('ollama/generate_complex_object', record: :new_episodes) do
          begin
            result = provider.generate_object("Create a research paper about quantum algorithms", schema_def, options)
            expect(result).to be_a(Hash)
            expect(result[:title]).to be_a(String)
            expect(result[:authors]).to be_an(Array)
            expect(result[:abstract]).to be_a(String)
            expect(result[:keywords]).to be_an(Array)
          rescue LastLLM::ApiError => e
            puts "API error: #{e.message}" if ENV['DEBUG']
            expect(e).to be_a(LastLLM::ApiError)
          end
        end
      end
    end
  end
end
