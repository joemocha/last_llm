# frozen_string_literal: true

# Add lib to load path
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

Dir[File.expand_path('support/**/*.rb', __dir__)].each { |f| require f }

require 'bundler/setup'
require 'dotenv/load'
require 'last_llm'
require 'vcr'
require 'webmock/rspec'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Run specs in random order
  config.order = :random
  Kernel.srand config.seed
end

VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
end
