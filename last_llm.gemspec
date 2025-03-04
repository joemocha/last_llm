# frozen_string_literal: true

require_relative 'lib/last_llm/version'

Gem::Specification.new do |spec|
  spec.name        = 'last_llm'
  spec.version     = LastLLM::VERSION
  spec.authors     = ['Sam Obukwelu']
  spec.email       = ['sam@obukwelu.com']
  spec.summary     = 'Last LLM'
  spec.description = 'A unified client for interacting with various LLM providers'
  spec.homepage    = 'https://github.com/joemocha/last_llm'
  spec.license     = 'MIT'
  spec.required_ruby_version = '>= 3.0'

  spec.files         = Dir['lib/**/*', 'README.md']
  spec.require_paths = ['lib']

  spec.add_dependency 'dry-schema', '~> 1.6'
  spec.add_dependency 'faraday', '~> 2.0'
  spec.add_dependency 'json', '~> 2.0'

  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'vcr', '~> 6.0'
  spec.add_development_dependency 'webmock', '~> 3.18'
end
