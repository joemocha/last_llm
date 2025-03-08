# frozen_string_literal: true

# Add lib to load path
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

Dir[File.expand_path('support/**/*.rb', __dir__)].each { |f| require f }

require 'bundler/setup'
require 'dotenv/load'
require 'last_llm'
require 'vcr'
require 'webmock/rspec'
require 'pry-byebug'
require 'logger'

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

  config.before(:each) do
    # Set up file logger for tests
    log_dir = File.expand_path('../log', __dir__)
    FileUtils.mkdir_p(log_dir)
    log_file = File.join(log_dir, 'test.log')
    puts "Setting up logger to write to: #{log_file}" # Debug print
    test_logger = Logger.new(log_file)
    test_logger.level = :debug

    # Verify logger is writing
    test_logger.debug("Logger initialization test")

    LastLLM.configure do |c|
      c.instance_variable_set(:@test_mode, true)
      c.logger = test_logger
      c.log_level = :debug
    end
  end
end

VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
end
