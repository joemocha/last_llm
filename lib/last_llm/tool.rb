# frozen_string_literal: true

module LastLLM
  # Error raised when tool parameter validation fails
  class ToolValidationError < ValidationError; end

  # Tool class for defining callable functions that can be used with LLM providers
  class Tool
    attr_reader :name, :description, :parameters, :function

    # Initialize a new tool
    # @param name [String] The name of the tool
    # @param description [String] A description of what the tool does
    # @param parameters [Hash] JSON Schema for the tool parameters
    # @param function [Proc] The function to execute when the tool is called
    def initialize(name:, description:, parameters:, function:)
      validate_initialization_params(name, description, parameters, function)

      @name = name
      @description = description
      @parameters = parameters
      @function = function
    end

    # Call the tool with the provided parameters
    # @param params [Hash] Parameters to pass to the tool function
    # @return [Hash] The result of the function call
    def call(params)
      # Convert string keys to symbols
      params = symbolize_keys(params)

      # Validate parameters against the schema
      validate_parameters(params)

      # Convert parameter types if needed
      converted_params = convert_parameter_types(params)

      # Execute the function
      function.call(converted_params)
    end

    private

    def validate_initialization_params(name, description, parameters, function)
      missing_params = []
      missing_params << "name" unless name.is_a?(String) && !name.empty?
      missing_params << "description" unless description.is_a?(String) && !description.empty?
      missing_params << "parameters" unless parameters.is_a?(Hash) && !parameters.empty?
      missing_params << "function" unless function.respond_to?(:call)

      unless missing_params.empty?
        raise ArgumentError, "Missing or invalid required attributes: #{missing_params.join(', ')}"
      end
    end

    def validate_parameters(params)
      # Basic validation for required parameters
      if parameters[:required].is_a?(Array)
        parameters[:required].each do |required_param|
          unless params.key?(required_param.to_sym)
            raise ToolValidationError, "Missing required parameter: #{required_param}"
          end
        end
      end

      # Validate enum values if present
      if parameters[:properties].is_a?(Hash)
        parameters[:properties].each do |prop_name, prop_schema|
          next unless params.key?(prop_name.to_sym) && prop_schema[:enum].is_a?(Array)

          param_value = params[prop_name.to_sym]
          unless prop_schema[:enum].include?(param_value)
            raise ToolValidationError, "Invalid value for #{prop_name}: #{param_value}. " \
                                      "Allowed values: #{prop_schema[:enum].join(', ')}"
          end
        end
      end
    end

    def convert_parameter_types(params)
      converted_params = params.dup

      parameters[:properties].each do |prop_name, prop_schema|
        next unless params.key?(prop_name.to_sym)

        param_value = params[prop_name.to_sym]
        prop_name_sym = prop_name.to_sym

        case prop_schema[:type]
        when "number", "integer"
          converted_params[prop_name_sym] = param_value.to_f if param_value.is_a?(String)
          converted_params[prop_name_sym] = param_value.to_i if prop_schema[:type] == "integer" && param_value.is_a?(Float)
        when "boolean"
          if param_value.is_a?(String)
            converted_params[prop_name_sym] = (param_value.downcase == "true")
          end
        end
      end

      converted_params
    end

    def symbolize_keys(hash)
      return hash unless hash.is_a?(Hash)

      hash.each_with_object({}) do |(key, value), result|
        result[key.to_sym] = value
      end
    end
  end
end
