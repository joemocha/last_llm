require 'spec_helper'
require 'vcr'

RSpec.describe LastLLM::Providers::Deepseek do
  let(:config) { { api_key: ENV['DEEPSEEK_API_KEY'] || 'test-key' } }
  let(:provider) { described_class.new(config) }
  let(:prompt) { 'Say "hello" using the fewest words possible' }
  let(:options) { { temperature: 0.5 } }

  before do
    VCR.configure do |c|
      c.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
      c.hook_into :webmock
      c.configure_rspec_metadata!
      c.filter_sensitive_data('<DEEPSEEK_API_KEY>') { ENV['DEEPSEEK_API_KEY'] || 'test-key' }
    end
  end

  it_behaves_like "provider options handling"

  describe '#generate_text' do
    it 'returns text completion from Deepseek' do
      VCR.use_cassette('deepseek/generate_text', match_requests_on: [:method, :uri]) do
        result = provider.generate_text(prompt, options)
        expect(result).to be_a(String)
        expect(result.length).to be > 0
        # Test content relevance
        expect(result.downcase.gsub('.', '')).to include('hello')
        expect(result).not_to include('error')
      end
    end

    describe 'with system prompt' do
      let(:prompt) { 'Say "hello" using the fewest words possible, no punctuation.' }
      it 'handles system prompts correctly' do
        options_with_system = options.merge(system_prompt: 'You are a helpful assistant, in french')
        result = nil
        VCR.use_cassette('deepseek/generate_text_with_system', match_requests_on: [:method, :uri]) do
          result = provider.generate_text(prompt, options_with_system)
          expect(result).to be_a(String)
          expect(result.length).to be > 0
          expect(['bonjour', 'salut']).to include(result.downcase)
        end

        # Compare with response without system prompt
        standard_result = nil
        VCR.use_cassette('deepseek/generate_text_comparison', match_requests_on: [:method, :uri]) do
          standard_result = provider.generate_text(prompt, options)
        end

        expect(result).not_to eq(standard_result)
      end
    end

    it 'raises an error on API failure' do
      invalid_provider = described_class.new({ api_key: 'invalid-key' })
      VCR.use_cassette('deepseek/api_error', record: :new_episodes) do
        begin
          invalid_provider.generate_text(prompt, options)
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

      it 'returns structured data from Deepseek' do
        VCR.use_cassette('deepseek/generate_object', record: :new_episodes) do
          result = provider.generate_object("Create a profile for John Doe, age 30", schema_def, options)
          expect(result).to be_a(Hash)
          expect(result[:name]).to be_a(String)
          expect(result[:age]).to be_a(Integer)
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
        VCR.use_cassette('deepseek/generate_complex_object', record: :new_episodes) do
          result = provider.generate_object("Create a research paper about quantum algorithms", schema_def, options)
          expect(result).to be_a(Hash)
          expect(result[:title]).to be_a(String)
          expect(result[:authors]).to be_an(Array)
          expect(result[:abstract]).to be_a(String)
          expect(result[:keywords]).to be_an(Array)
        end
      end
    end
  end
end
