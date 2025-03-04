# frozen_string_literal: true

source "https://rubygems.org"

gem "rake", "~> 13.0"
gem 'dry-monads', '~> 1.6'
gem 'dry-schema', '~> 1.6'

gem 'faraday'
gem 'typhoeus'
gem 'faraday-typhoeus'

gem 'activesupport', '~> 8.0'

group :development do
  gem "rubocop", "~> 1.50"
  gem "yard", "~> 0.9.34"
end

group :test do
  gem "rspec", "~> 3.12"
  gem 'vcr'
  gem 'webmock'
  gem "simplecov", "~> 0.22.0", require: false
  gem 'dotenv', '~> 2.8'
end
