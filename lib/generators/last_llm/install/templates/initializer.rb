# frozen_string_literal: true

# Configure LastLLM
LastLLM.configure do |config|
  # Load configuration from config/last_llm.yml
  config_file = Rails.root.join('config', 'last_llm.yml')
  if File.exist?(config_file)
    yaml_config = YAML.safe_load_file(config_file, symbolize_names: true)
    
    # Set default provider
    config.default_provider = yaml_config[:default_provider].to_sym if yaml_config[:default_provider]
    
    # Set default model
    config.default_model = yaml_config[:default_model] if yaml_config[:default_model]
    
    # Configure providers
    yaml_config[:providers]&.each do |provider, settings|
      settings.each do |key, value|
        config.set_provider_config(provider, key, value)
      end
    end
    
    # Configure global settings
    yaml_config[:globals]&.each do |key, value|
      config.set_global(key.to_sym, value)
    end
  end
end