# frozen_string_literal: true

RSpec.shared_examples "provider options handling" do
  let(:base_prompt) { "Hello, world!" }
  let(:base_config) { { api_key: "test-key" } }

  describe "option handling" do
    let(:provider) { described_class.new(base_config) }
    let(:fake_response) { instance_double(Faraday::Response, status: 200, body: JSON.parse('{"content": [{"text": "response"}]}')) }

    before do
      # Stub the Faraday connection POST request to avoid actual API calls
      allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(fake_response)
    end

    context "with model option" do
      it "uses provided model over default" do
        options = { model: "custom-model" }

        expect_any_instance_of(Faraday::Connection).to receive(:post).with(anything) do |_, _, &block|
          req = double('request', body: nil)
          expect(req).to receive(:body=) do |body_params|
            expect(body_params[:model]).to eq("custom-model")
          end
          block.call(req)
          fake_response
        end

        provider.generate_text(base_prompt, options)
      end
    end

    context "with temperature option" do
      it "uses provided temperature over default" do
        options = { temperature: 0.8 }

        expect_any_instance_of(Faraday::Connection).to receive(:post).with(anything) do |_, _, &block|
          req = double('request', body: nil)
          expect(req).to receive(:body=) do |body_params|
            expect(body_params[:temperature]).to eq(0.8)
          end
          block.call(req)
          fake_response
        end

        provider.generate_text(base_prompt, options)
      end
    end

    context "with max_tokens option" do
      it "uses provided max_tokens over default" do
        options = { max_tokens: 100 }

        expect_any_instance_of(Faraday::Connection).to receive(:post).with(anything) do |_, _, &block|
          req = double('request', body: nil)
          expect(req).to receive(:body=) do |body_params|
            expect(body_params[:max_tokens]).to eq(100)
          end
          block.call(req)
          fake_response
        end

        provider.generate_text(base_prompt, options)
      end
    end

    context "with multiple options" do
      it "merges all provided options with defaults" do
        options = {
          model: "custom-model",
          temperature: 0.8,
          max_tokens: 100,
          top_p: 0.9
        }

        expect_any_instance_of(Faraday::Connection).to receive(:post).with(anything) do |_, _, &block|
          req = double('request', body: nil)
          expect(req).to receive(:body=) do |body_params|
            expect(body_params[:model]).to eq("custom-model")
            expect(body_params[:temperature]).to eq(0.8)
            expect(body_params[:max_tokens]).to eq(100)
            expect(body_params[:top_p]).to eq(0.9)
          end
          block.call(req)
          fake_response
        end

        provider.generate_text(base_prompt, options)
      end
    end
  end
end
