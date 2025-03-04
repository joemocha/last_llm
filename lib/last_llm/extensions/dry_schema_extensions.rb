# frozen_string_literal: true

# Monkey patch Dry::Schema::JSON to add json_schema method
module Dry
  module Schema
    class JSON
      # Convert the schema to a JSON schema hash
      # @return [Hash] The JSON schema hash
      def json_schema
        # Extract schema information
        json_schema = {
          type: 'object',
          properties: {},
          required: []
        }

        # Process each rule in the schema
        rules.each_value do |rule|
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

        json_schema
      end
    end
  end
end
