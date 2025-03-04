# frozen_string_literal: true
require 'rails'

# This file defines the Railtie constant directly to be compatible with Zeitwerk
# Rails integration for LastLLM
class Railtie < Rails::Railtie
  generators do
    require 'generators/last_llm/install/install_generator'
  end

  initializer "last_llm.configure_rails_initialization" do
    # Load configuration from config/last_llm.yml if it exists
    config_file = Rails.root.join('config', 'last_llm.yml')
    if File.exist?(config_file)
      config = YAML.safe_load(File.read(config_file), symbolize_names: true)

      # Configure LastLLM with the loaded configuration
      LastLLM.configure do |c|
        # Set global configuration
        if config[:default_provider]
          c.default_provider = config[:default_provider].to_sym
        end

        if config[:default_model]
          c.default_model = config[:default_model]
        end

        # Configure global settings
        if config[:globals]
          config[:globals].each do |key, value|
            c.set_global(key.to_sym, value)
          end
        end
      end
    end
  end
end

# Also define it in the LastLLM namespace for backward compatibility
module LastLLM
  # Reference to the Railtie class defined above
  Railtie = ::Railtie
end
