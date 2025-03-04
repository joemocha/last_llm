require 'spec_helper'

RSpec.describe LastLLM::Tool do
  let(:calculator_tool) do
    described_class.new(
      name: "calculator",
      description: "Perform mathematical calculations",
      parameters: {
        type: "object",
        properties: {
          operation: {
            type: "string",
            enum: ["add", "subtract", "multiply", "divide"],
            description: "The operation to perform"
          },
          a: {
            type: "number",
            description: "First operand"
          },
          b: {
            type: "number",
            description: "Second operand"
          }
        },
        required: ["operation", "a", "b"]
      },
      function: ->(params) {
        case params[:operation]
        when "add"
          { result: params[:a] + params[:b] }
        when "subtract"
          { result: params[:a] - params[:b] }
        when "multiply"
          { result: params[:a] * params[:b] }
        when "divide"
          { result: params[:a] / params[:b] }
        end
      }
    )
  end

  describe "#initialize" do
    it "creates a tool with a name, description, parameters schema and function" do
      expect(calculator_tool.name).to eq("calculator")
      expect(calculator_tool.description).to eq("Perform mathematical calculations")
      expect(calculator_tool.parameters).to be_a(Hash)
      expect(calculator_tool.function).to be_a(Proc)
    end

    it "raises an error if required attributes are missing" do
      expect {
        described_class.new(
          name: "calculator",
          description: "Perform calculations"
          # Missing parameters and function
        )
      }.to raise_error(ArgumentError)
    end
  end

  describe "#call" do
    it "executes the function with provided parameters" do
      result = calculator_tool.call(
        operation: "add",
        a: 5,
        b: 3
      )
      expect(result).to eq({ result: 8 })
    end

    it "validates parameters against the schema" do
      expect {
        calculator_tool.call(
          operation: "invalid_op",
          a: 5,
          b: 3
        )
      }.to raise_error(LastLLM::ToolValidationError)
    end

    it "handles parameter type conversion" do
      result = calculator_tool.call(
        operation: "add",
        a: "5", # String that should be converted to number
        b: 3
      )
      expect(result).to eq({ result: 8 })
    end
  end

  describe "OpenAI.format_tool" do
    it "formats the tool for OpenAI function calling" do
      openai_format = LastLLM::Providers::OpenAI.format_tool(calculator_tool)
      expect(openai_format[:type]).to eq("function")
      expect(openai_format[:function][:name]).to eq("calculator")
      expect(openai_format[:function][:description]).to eq("Perform mathematical calculations")
      expect(openai_format[:function][:parameters]).to eq(calculator_tool.parameters)
    end
  end

  describe "Anthropic.format_tool" do
    it "formats the tool for Anthropic tools format" do
      anthropic_format = LastLLM::Providers::Anthropic.format_tool(calculator_tool)
      expect(anthropic_format[:name]).to eq("calculator")
      expect(anthropic_format[:description]).to eq("Perform mathematical calculations")
      expect(anthropic_format[:input_schema]).to eq(calculator_tool.parameters)
    end
  end

  describe "OpenAI.execute_tool" do
    it "executes the tool from an OpenAI-format response" do
      openai_response = {
        tool_calls: [{
          function: {
            name: "calculator",
            arguments: '{"operation":"add","a":5,"b":3}'
          }
        }]
      }
      result = LastLLM::Providers::OpenAI.execute_tool(calculator_tool, openai_response)
      expect(result).to eq({ result: 8 })
    end
  end

  describe "Anthropic.execute_tool" do
    it "executes the tool from an Anthropic-format response" do
      anthropic_response = {
        tool_use: {
          name: "calculator",
          input: {
            operation: "multiply",
            a: 4,
            b: 2
          }
        }
      }
      result = LastLLM::Providers::Anthropic.execute_tool(calculator_tool, anthropic_response)
      expect(result).to eq({ result: 8 })
    end
  end
end
