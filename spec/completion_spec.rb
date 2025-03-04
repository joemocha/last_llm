require 'spec_helper'

RSpec.describe LastLLM::Completion do
  # Setup test variables
  let(:prompt) { "Tell me about Ruby programming" }
  let(:options) { { model: "gpt-4", temperature: 0.7, max_tokens: 500 } }

  # We need a client for the completion to use
  let(:client) do
    config = LastLLM::Configuration.new(test_mode: true)
    config.configure_provider(:test, {})
    LastLLM::Client.new(config, provider: :test)
  end
  let(:completion) { LastLLM::Completion.new(client) }

  describe "#initialize" do
    it "initializes with a client" do
      expect(completion.instance_variable_get(:@client)).to eq(client)
    end
  end

  describe "#generate", :vcr do
    it "generates text completion" do
      VCR.use_cassette("last_llm_completion_generate") do
        result = completion.generate(prompt, options)
        expect(result).to be_a(String)
        expect(result).not_to be_empty
      end
    end

    it "accepts options" do
      VCR.use_cassette("last_llm_completion_with_options") do
        expect { completion.generate(prompt, options) }.not_to raise_error
      end
    end

    it "works with minimal options" do
      VCR.use_cassette("last_llm_completion_minimal_options") do
        expect { completion.generate(prompt) }.not_to raise_error
      end
    end
  end
end
