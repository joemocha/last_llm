# ...existing code...

def log_request(prompt)
  LastLlm.logger.debug "LLM request: #{prompt}"
end

def log_response(response)
  LastLlm.logger.debug "LLM response: #{response}"
end

def query(prompt, config = {})
  log_request(prompt)

  begin
    response = client.complete(prompt, **config)
    log_response(response)
    response
  rescue => e
    LastLlm.logger.error "LLM error: #{e.message}"
    raise
  end
end

# ...existing code...
