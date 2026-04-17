#' Agentic loop — tool use + iteration
#'
#' This is the core research-agent logic. Given a user message, it:
#'   1. Calls Claude with the user's tools list
#'   2. If Claude's response contains tool_use blocks, executes each one
#'   3. Appends the tool results as a user message
#'   4. Calls Claude again with the expanded conversation
#'   5. Repeats until Claude responds with no tool_use blocks (final answer)
#'
#' UI callbacks let the chat gadget stream text and show tool activity
#' as it happens.

MAX_AGENT_ITERATIONS <- 8L

#' Run the agentic loop for one user turn
#'
#' @param messages Current conversation as a list of {role, content} entries.
#'   The caller should append the new user message before calling this.
#' @param on_text_chunk Function called with each streamed text chunk
#' @param on_tool_start Function called when a tool begins: fn(name, id)
#' @param on_tool_result Function called when a tool completes: fn(name, id, result)
#' @param on_iteration Function called at the start of each loop: fn(iter)
#'
#' @return List with fields:
#'   - messages: full conversation including all assistant/tool turns
#'   - final_text: the final textual response to show the user
#'   - iterations: how many API calls were made
#'
#' @keywords internal
run_agentic_turn <- function(messages,
                             on_text_chunk = function(chunk) invisible(),
                             on_tool_start = function(name, id) invisible(),
                             on_tool_result = function(name, id, result) invisible(),
                             on_iteration = function(iter) invisible()) {
  context <- gather_context()
  system_prompt <- build_system_prompt(context)
  tools <- tool_definitions()

  final_text_parts <- character()

  for (iter in seq_len(MAX_AGENT_ITERATIONS)) {
    on_iteration(iter)

    response <- call_claude_streaming(
      system_prompt = system_prompt,
      messages = messages,
      tools = tools,
      on_text_chunk = on_text_chunk,
      on_tool_start = on_tool_start,
      max_tokens = 2048
    )

    # Record assistant turn (full content array — needed for tool_use continuity)
    messages <- c(messages, list(list(
      role = "assistant",
      content = response$content
    )))

    # Gather text blocks for final display
    text_blocks <- Filter(function(b) b$type == "text", response$content)
    for (b in text_blocks) {
      final_text_parts <- c(final_text_parts, b$text)
    }

    # If Claude is done (no tool calls), exit loop
    tool_calls <- Filter(function(b) b$type == "tool_use", response$content)
    if (length(tool_calls) == 0) break

    # Execute each tool, collect results
    tool_results <- list()
    for (call in tool_calls) {
      result <- execute_tool(call$name, call$input)
      on_tool_result(call$name, call$id, result)
      tool_results[[length(tool_results) + 1]] <- list(
        type = "tool_result",
        tool_use_id = call$id,
        content = result
      )
    }

    # Feed results back as a user message
    messages <- c(messages, list(list(
      role = "user",
      content = tool_results
    )))
  }

  list(
    messages = messages,
    final_text = paste(final_text_parts, collapse = "\n\n"),
    iterations = iter
  )
}
