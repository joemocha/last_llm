# frozen_string_literal: true

require 'rails/generators'

module LastLLM
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      desc 'Creates a LastLLM configuration file and initializer'

      def create_config_file
        template 'last_llm.yml', 'config/last_llm.yml'
      end

      def create_initializer
        template 'initializer.rb', 'config/initializers/last_llm.rb'
      end

      def show_readme
        readme 'README.md'
      end
    end
  end
end