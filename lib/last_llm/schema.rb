# frozen_string_literal: true
require 'dry-schema'
require 'json'

module LastLLM
  # Schema utilities for structured data generation
  class Schema
    # Create a dry-schema from a hash definition
    # @param schema_def [Hash] The schema definition in JSON Schema format
    # @return [Dry::Schema::JSON] The created schema
    def self.create(schema_def)
      # Convert JSON Schema to dry-schema
      schema = Dry::Schema.JSON do
        # Process properties
        if schema_def[:properties] || schema_def['properties']
          properties = schema_def[:properties] || schema_def['properties']
          required = schema_def[:required] || schema_def['required'] || []

          properties.each do |property_name, property_def|
            property_name = property_name.to_sym
            property_type = property_def[:type] || property_def['type']

            # Handle required properties
            if required.include?(property_name.to_s)
              # Handle different property types
              case property_type
              when 'string'
                required(property_name).filled(:string)
              when 'integer'
                required(property_name).filled(:integer)
              when 'number'
                required(property_name).filled(:float)
              when 'boolean'
                required(property_name).filled(:bool)
              when 'array'
                items_type = property_def.dig(:items, :type) || property_def.dig('items', 'type')
                case items_type
                when 'string'
                  required(property_name).array(:string)
                when 'integer'
                  required(property_name).array(:integer)
                when 'number'
                  required(property_name).array(:float)
                when 'boolean'
                  required(property_name).array(:bool)
                when 'object'
                  # For complex nested objects, we'd need a more sophisticated approach
                  # This is a simplified version
                  required(property_name).array(:hash)
                else
                  required(property_name).array
                end
              when 'object'
                # For nested objects, we can't recursively create a schema here
                # Instead, we'll just create a hash schema
                required(property_name).hash do
                  # Add nested properties if available
                  if property_def[:properties] || property_def['properties']
                    nested_props = property_def[:properties] || property_def['properties']
                    nested_required = property_def[:required] || property_def['required'] || []

                    nested_props.each do |nested_name, nested_def|
                      nested_name = nested_name.to_sym
                      nested_type = nested_def[:type] || nested_def['type']

                      if nested_required.include?(nested_name.to_s)
                        case nested_type
                        when 'string'
                          required(nested_name).filled(:string)
                        when 'integer'
                          required(nested_name).filled(:integer)
                        when 'number'
                          required(nested_name).filled(:float)
                        when 'boolean'
                          required(nested_name).filled(:bool)
                        else
                          required(nested_name).filled
                        end
                      else
                        optional(nested_name)
                      end
                    end
                  end
                end
              else
                required(property_name).filled
              end
            else
              # Handle optional properties
              case property_type
              when 'string'
                optional(property_name).maybe(:string)
              when 'integer'
                optional(property_name).maybe(:integer)
              when 'number'
                optional(property_name).maybe(:float)
              when 'boolean'
                optional(property_name).maybe(:bool)
              when 'array'
                items_type = property_def.dig(:items, :type) || property_def.dig('items', 'type')
                case items_type
                when 'string'
                  optional(property_name).maybe(:array, :string)
                when 'integer'
                  optional(property_name).maybe(:array, :integer)
                when 'number'
                  optional(property_name).maybe(:array, :float)
                when 'boolean'
                  optional(property_name).maybe(:array, :bool)
                when 'object'
                  optional(property_name).maybe(:array, :hash)
                else
                  optional(property_name).maybe(:array)
                end
              when 'object'
                # For nested objects, we can't recursively create a schema here
                # Instead, we'll just create a hash schema
                optional(property_name).maybe(:hash) do
                  # Add nested properties if available
                  if property_def[:properties] || property_def['properties']
                    nested_props = property_def[:properties] || property_def['properties']
                    nested_required = property_def[:required] || property_def['required'] || []

                    nested_props.each do |nested_name, nested_def|
                      nested_name = nested_name.to_sym
                      nested_type = nested_def[:type] || nested_def['type']

                      if nested_required.include?(nested_name.to_s)
                        case nested_type
                        when 'string'
                          required(nested_name).filled(:string)
                        when 'integer'
                          required(nested_name).filled(:integer)
                        when 'number'
                          required(nested_name).filled(:float)
                        when 'boolean'
                          required(nested_name).filled(:bool)
                        else
                          required(nested_name).filled
                        end
                      else
                        optional(nested_name)
                      end
                    end
                  end
                end
              else
                optional(property_name)
              end
            end
          end
        end
      end

      schema
    end

    # Convert a JSON schema string to a dry-schema
    # @param json_schema [String] The JSON schema as a string
    # @return [Dry::Schema::JSON] The created schema
    def self.from_json_schema(json_schema)
      schema_def = JSON.parse(json_schema, symbolize_names: true)
      create(schema_def)
    end

    # Convert a dry-schema to a JSON schema string
    # @param schema [Dry::Schema::JSON, Hash] The dry-schema or JSON schema hash to convert
    # @return [String] The JSON schema as a string
    def self.to_json_schema(schema)
      # If schema is already a Hash, assume it's a JSON schema
      if schema.is_a?(Hash)
        return JSON.pretty_generate(schema)
      end

      # If schema has a json_schema method, use it
      if schema.respond_to?(:json_schema)
        return JSON.pretty_generate(schema.json_schema)
      end

      # Otherwise, extract schema information from dry-schema
      json_schema = {
        type: 'object',
        properties: {},
        required: []
      }

      # Process each rule in the schema
      if schema.respond_to?(:rules) && schema.rules.respond_to?(:each_value)
        schema.rules.each_value do |rule|
          # Skip if rule is not a proper rule object
          next unless rule.respond_to?(:name)

          property_name = rule.name.to_s
          property_def = {}

          # Determine if the property is required
          if rule.is_a?(Dry::Schema::Rule::Required)
            json_schema[:required] << property_name
          end

          # Determine the property type
          if rule.respond_to?(:type) && rule.type.is_a?(Dry::Types::Nominal)
            case rule.type.primitive
            when String
              property_def['type'] = 'string'
            when Integer
              property_def['type'] = 'integer'
            when Float
              property_def['type'] = 'number'
            when TrueClass, FalseClass
              property_def['type'] = 'boolean'
            when Array
              property_def['type'] = 'array'
              # Try to determine the item type
              if rule.type.respond_to?(:member) && rule.type.member.respond_to?(:primitive)
                case rule.type.member.primitive
                when String
                  property_def['items'] = { 'type' => 'string' }
                when Integer
                  property_def['items'] = { 'type' => 'integer' }
                when Float
                  property_def['items'] = { 'type' => 'number' }
                when TrueClass, FalseClass
                  property_def['items'] = { 'type' => 'boolean' }
                when Hash
                  property_def['items'] = { 'type' => 'object' }
                else
                  property_def['items'] = {}
                end
              else
                property_def['items'] = {}
              end
            when Hash
              property_def['type'] = 'object'
              # For nested objects, we'd need a more sophisticated approach
            else
              property_def['type'] = 'string' # Default to string
            end
          end

          json_schema[:properties][property_name] = property_def
        end
      end

      JSON.pretty_generate(json_schema)
    end
  end
end
