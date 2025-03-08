# frozen_string_literal: true

require 'spec_helper'
require 'vcr'

RSpec.describe LastLLM::Providers::GoogleGemini do
  let(:config) { { api_key: ENV['GOOGLE_API_KEY'] || 'test-key' } }
  let(:provider) { described_class.new(config) }
  let(:prompt) { 'Say "hello" using the fewest words possible' }
  let(:options) { { temperature: 0.5 } }

  before do
    VCR.configure do |c|
      c.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
      c.hook_into :webmock
      c.configure_rspec_metadata!
      c.filter_sensitive_data('<GOOGLE_API_KEY>') { ENV['GOOGLE_API_KEY'] || 'test-key' }
      c.default_cassette_options = {
        match_requests_on: %i[method path body],
        record: :new_episodes
      }
    end
  end

  describe 'logging' do
    it 'logs provider initialization' do
      LastLLM.configuration.logger.debug("Testing Google Gemini provider logging")
      new_provider = described_class.new(config)
      expect(File.read('log/test.log')).to include('Initialized Google Gemini provider')
    end

    it 'logs text generation request' do
      VCR.use_cassette('google_gemini/generate_text_logging') do
        provider.generate_text(prompt, options)
        log_content = File.read('log/test.log')
        expect(log_content).to include('Generating text with model:')
        expect(log_content).to include('Text prompt:')
      end
    end
  end

  it_behaves_like 'gemini provider options handling'

  describe '#generate_text' do
    it 'returns text completion from Google Gemini' do
      VCR.use_cassette('google_gemini/generate_text', match_requests_on: %i[method uri]) do
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
        VCR.use_cassette('google_gemini/generate_text_with_system', match_requests_on: %i[method uri]) do
          result = provider.generate_text(prompt, options_with_system)
          expect(result).to be_a(String)
          expect(result.length).to be > 0
          expect(result.downcase).to match(/Bonjour|Salut/i)
        end

        # Compare with response without system prompt
        standard_result = nil
        VCR.use_cassette('google_gemini/generate_text_comparison', match_requests_on: %i[method uri]) do
          standard_result = provider.generate_text(prompt, options)
        end

        expect(result).not_to eq(standard_result)
      end
    end

    it 'raises an error on API failure' do
      invalid_provider = described_class.new({ api_key: 'invalid-key' })
      VCR.use_cassette('google_gemini/api_error') do
        invalid_provider.generate_text(prompt, options)
        raise 'Expected an error to be raised'
      rescue LastLLM::ApiError => e
        expect(e).to be_a(LastLLM::ApiError)
        expect(e.message).to include('API') || include('key') || include('auth')
        expect(e.status_code).to be_a(Integer) if e.respond_to?(:status_code)
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
          required: %w[name age]
        }
      end

      it 'returns structured data from Google Gemini' do
        VCR.use_cassette('google_gemini/generate_object', record: :new_episodes) do
          result = provider.generate_object('Create a profile for John Doe, age 30', schema_def, options)
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
          required: %w[title authors abstract keywords]
        }
      end

      it 'returns properly structured complex data' do
        VCR.use_cassette('google_gemini/generate_complex_object', record: :new_episodes) do
          result = provider.generate_object('Create a research paper about quantum algorithms', schema_def, options)
          expect(result).to be_a(Hash)
          expect(result[:title]).to be_a(String)
          expect(result[:authors]).to be_an(Array)
          expect(result[:abstract]).to be_a(String)
          expect(result[:keywords]).to be_an(Array)
        end
      end
    end
  end

  describe '.format_tool' do
    let(:tool) do
      LastLLM::Tool.new(
        name: 'test_tool',
        description: 'A test tool',
        parameters: {
          type: 'object',
          properties: {
            param1: { type: 'string' }
          },
          required: ['param1']
        },
        function: ->(params) { { result: params[:param1] } }
      )
    end

    it 'formats a tool for Google Gemini' do
      formatted = described_class.format_tool(tool)
      expect(formatted).to be_a(Hash)
      expect(formatted[:name]).to eq('test_tool')
      expect(formatted[:description]).to eq('A test tool')
      expect(formatted[:parameters]).to be_a(Hash)
    end
  end

  describe '.execute_tool' do
    let(:tool) do
      LastLLM::Tool.new(
        name: 'test_tool',
        description: 'A test tool',
        parameters: {
          type: 'object',
          properties: {
            param1: { type: 'string' }
          },
          required: ['param1']
        },
        function: ->(params) { { result: params[:param1] } }
      )
    end

    it 'executes a tool from a Google Gemini response' do
      response = {
        candidates: [{
          content: {
            parts: [{
              functionCall: {
                name: 'test_tool',
                args: { param1: 'test_value' }
              }
            }]
          }
        }]
      }

      result = described_class.execute_tool(tool, response)
      expect(result).to eq({ result: 'test_value' })
    end

    it 'returns nil if the tool was not called' do
      response = {
        candidates: [{
          content: {
            parts: [{
              text: 'No tool call'
            }]
          }
        }]
      }
      result = described_class.execute_tool(tool, response)
      expect(result).to be_nil
    end
  end
end
