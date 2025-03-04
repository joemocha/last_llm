# LastLlm

LastLlm is a unified client for interacting with various LLM (Large Language Model) providers. It provides a consistent interface for text generation, structured data generation, and tool calling across different LLM services.

## Features

- Unified interface for multiple LLM providers:
  - OpenAI
  - Anthropic
  - Google Gemini
  - Deepseek
  - Ollama
- Text generation
- Structured data generation with schema validation
- Tool/function calling support
- Rails integration
- Configuration management
- Error handling

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'last_llm'
```

## Configuration

Configure LastLlm globally or per instance:

```ruby
LastLlm.configure do |config|
  config.default_provider = :openai
  config.default_model = 'gpt-3.5-turbo'

  # Configure OpenAI
  config.configure_provider(:openai, api_key: 'your-api-key')

  # Configure Anthropic
  config.configure_provider(:anthropic, api_key: 'your-api-key')

  # Configure Ollama
  config.configure_provider(:ollama, host: 'http://localhost:11434')
end
```

### Rails Integration

LastLlm automatically integrates with Rails applications. Create a `config/last_llm.yml` file:

```yaml
default_provider: openai
default_model: gpt-3.5-turbo
globals:
  timeout: 30
  max_retries: 3
```

## Usage

### Basic Text Generation

```ruby
client = LastLlm.client
response = client.generate_text("What is the capital of France?")
```

### Structured Data Generation

```ruby
schema = Dry::Schema.JSON do
  required(:name).filled(:string)
  required(:age).filled(:integer)
  optional(:email).maybe(:string)
end

client = LastLlm.client
result = client.generate_object("Generate information about a person", schema)
```

### Tool Calling

```ruby
calculator = LastLlm::Tool.new(
  name: "calculator",
  description: "Perform mathematical calculations",
  parameters: {
    type: "object",
    properties: {
      operation: {
        type: "string",
        enum: ["add", "subtract", "multiply", "divide"]
      },
      a: { type: "number" },
      b: { type: "number" }
    },
    required: ["operation", "a", "b"]
  },
  function: ->(params) {
    case params[:operation]
    when "add"
      { result: params[:a] + params[:b] }
    end
  }
)
```

## Error Handling

LastLlm provides several error classes:
- `LastLlm::Error`: Base error class
- `LastLlm::ConfigurationError`: Configuration-related errors
- `LastLlm::ValidationError`: Schema validation errors
- `LastLlm::ApiError`: API request errors

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `rspec` to run the tests.

## Contributing

Bug reports and pull requests are welcome on GitHub.
# LastLlm

LastLlm is a unified client for interacting with various LLM (Large Language Model) providers. It provides a consistent interface for text generation, structured data generation, and tool calling across different LLM services.

## Features

- Unified interface for multiple LLM providers:
  - OpenAI
  - Anthropic
  - Google Gemini
  - Deepseek
  - Ollama
- Text generation
- Structured data generation with schema validation
- Tool/function calling support
- Rails integration
- Configuration management
- Error handling

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'last_llm'
```

## Configuration

Configure LastLlm globally or per instance:

```ruby
LastLlm.configure do |config|
  config.default_provider = :openai
  config.default_model = 'gpt-3.5-turbo'

  # Configure OpenAI
  config.configure_provider(:openai, api_key: 'your-api-key')

  # Configure Anthropic
  config.configure_provider(:anthropic, api_key: 'your-api-key')

  # Configure Ollama
  config.configure_provider(:ollama, host: 'http://localhost:11434')
end
```

### Rails Integration

LastLlm automatically integrates with Rails applications. Create a `config/last_llm.yml` file:

```yaml
default_provider: openai
default_model: gpt-3.5-turbo
globals:
  timeout: 30
  max_retries: 3
```

## Usage

### Basic Text Generation

```ruby
client = LastLlm.client
response = client.generate_text("What is the capital of France?")
```

### Structured Data Generation

```ruby
schema = Dry::Schema.JSON do
  required(:name).filled(:string)
  required(:age).filled(:integer)
  optional(:email).maybe(:string)
end

client = LastLlm.client
result = client.generate_object("Generate information about a person", schema)
```

### Tool Calling

```ruby
calculator = LastLlm::Tool.new(
  name: "calculator",
  description: "Perform mathematical calculations",
  parameters: {
    type: "object",
    properties: {
      operation: {
        type: "string",
        enum: ["add", "subtract", "multiply", "divide"]
      },
      a: { type: "number" },
      b: { type: "number" }
    },
    required: ["operation", "a", "b"]
  },
  function: ->(params) {
    case params[:operation]
    when "add"
      { result: params[:a] + params[:b] }
    end
  }
)
```

## Error Handling

LastLlm provides several error classes:
- `LastLlm::Error`: Base error class
- `LastLlm::ConfigurationError`: Configuration-related errors
- `LastLlm::ValidationError`: Schema validation errors
- `LastLlm::ApiError`: API request errors

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `rspec` to run the tests.

## Contributing

Bug reports and pull requests are welcome on GitHub.
