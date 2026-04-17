#' Provider dispatch — routes call_provider_streaming() to the right backend
#'
#' This is the single entry point the agent loop uses. It reads the active
#' provider from options() and delegates to the appropriate client.
#' Both Anthropic and OpenAI clients return Anthropic-format content blocks
#' so downstream code (agent loop, tool_result_to_content) is uniform.

#' Call the currently-active provider with streaming
#'
#' Same signature + return shape as `call_claude_streaming()`, but dispatches
#' to either the Anthropic or OpenAI client based on `getOption("sparx.provider")`.
#'
#' @keywords internal
call_provider_streaming <- function(system_prompt,
                                    messages,
                                    tools = NULL,
                                    on_text_chunk = function(chunk) invisible(),
                                    on_tool_start = function(name, id) invisible(),
                                    model = NULL,
                                    max_tokens = 2048) {
  provider <- get_provider()

  switch(
    provider,
    "anthropic" = call_claude_streaming(
      system_prompt = system_prompt,
      messages = messages,
      tools = tools,
      on_text_chunk = on_text_chunk,
      on_tool_start = on_tool_start,
      model = model,
      max_tokens = max_tokens
    ),
    "openai" = call_openai_streaming(
      system_prompt = system_prompt,
      messages = messages,
      tools = tools,
      on_text_chunk = on_text_chunk,
      on_tool_start = on_tool_start,
      model = model,
      max_tokens = max_tokens
    ),
    stop("Unsupported provider: ", provider)
  )
}
