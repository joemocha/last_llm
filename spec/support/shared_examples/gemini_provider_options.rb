# frozen_string_literal: true

RSpec.shared_examples 'gemini provider options handling' do
  let(:base_prompt) { 'Hello, world!' }
  let(:base_config) { { api_key: 'test-key' } }

  describe 'option handling' do
    let(:provider) { described_class.new(base_config) }
    let(:body) { JSON.parse('{"candidates": [{"content": {"parts": [{"text": "[\"response\"]"}]}}]}') }
    let(:fake_response) do
      instance_double(Faraday::Response, status: 200, body: body)
    end

    context 'with model option' do
      it 'uses provided model in the URL path' do
        options = { model: 'custom-gemini-model' }

        expect_any_instance_of(Faraday::Connection).to receive(:post)
          .with('/v1beta/models/custom-gemini-model:generateContent?key=test-key')
          .and_yield(double('request', body: nil).as_null_object)
          .and_return(fake_response)

        provider.generate_text(base_prompt, options)
      end
    end

    context 'with temperature option' do
      it 'places temperature in generationConfig' do
        options = { temperature: 0.8 }

        expect_any_instance_of(Faraday::Connection).to receive(:post) do |_, _url, &block|
          req = double('request', body: nil)
          expect(req).to receive(:body=) do |body_params|
            expect(body_params[:generationConfig][:temperature]).to eq(0.8)
          end
          block.call(req)
          fake_response
        end

        provider.generate_text(base_prompt, options)
      end
    end

    context 'with max_tokens option' do
      it 'converts to maxOutputTokens in generationConfig' do
        options = { max_tokens: 100 }

        expect_any_instance_of(Faraday::Connection).to receive(:post) do |_, _url, &block|
          req = double('request', body: nil)
          expect(req).to receive(:body=) do |body_params|
            expect(body_params[:generationConfig][:maxOutputTokens]).to eq(100)
          end
          block.call(req)
          fake_response
        end

        provider.generate_text(base_prompt, options)
      end
    end

    context 'with top_p option' do
      it 'converts to topP in generationConfig' do
        options = { top_p: 0.9 }

        expect_any_instance_of(Faraday::Connection).to receive(:post) do |_, _url, &block|
          req = double('request', body: nil)
          expect(req).to receive(:body=) do |body_params|
            expect(body_params[:generationConfig][:topP]).to eq(0.9)
          end
          block.call(req)
          fake_response
        end

        provider.generate_text(base_prompt, options)
      end
    end

    context 'with top_k option' do
      it 'converts to topK in generationConfig' do
        options = { top_k: 30 }

        expect_any_instance_of(Faraday::Connection).to receive(:post) do |_, _url, &block|
          req = double('request', body: nil)
          expect(req).to receive(:body=) do |body_params|
            expect(body_params[:generationConfig][:topK]).to eq(30)
          end
          block.call(req)
          fake_response
        end

        provider.generate_text(base_prompt, options)
      end
    end

    context 'with multiple options' do
      it 'correctly passes all options' do
        options = {
          model: 'custom-gemini-model',
          temperature: 0.8,
          max_tokens: 100,
          top_p: 0.9,
          top_k: 30
        }

        expect_any_instance_of(Faraday::Connection).to receive(:post) do |_, url, &block|
          expect(url).to eq('/v1beta/models/custom-gemini-model:generateContent?key=test-key')

          req = double('request', body: nil)
          expect(req).to receive(:body=) do |body_params|
            expect(body_params[:generationConfig][:temperature]).to eq(0.8)
            expect(body_params[:generationConfig][:maxOutputTokens]).to eq(100)
            expect(body_params[:generationConfig][:topP]).to eq(0.9)
            expect(body_params[:generationConfig][:topK]).to eq(30)
          end
          block.call(req)
          fake_response
        end

        provider.generate_text(base_prompt, options)
      end
    end

    context 'with generate_object' do
      let(:schema) { { type: 'object', properties: { name: { type: 'string' } } } }

      it 'includes responseSchema and responseMimeType in generationConfig' do
        options = { temperature: 0.2 }

        expect_any_instance_of(Faraday::Connection).to receive(:post) do |_, _url, &block|
          req = double('request', body: nil)
          expect(req).to receive(:body=) do |body_params|
            expect(body_params[:generationConfig][:responseMimeType]).to eq('application/json')
            expect(body_params[:generationConfig][:responseSchema]).to eq(schema)
          end
          block.call(req)
          fake_response
        end

        provider.generate_object(base_prompt, schema, options)
      end
    end
  end
end
