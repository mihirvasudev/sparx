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

MAX_AGENT_ITERATIONS <- 12L

# Package-level state for abort signaling + cumulative token usage
.sparx_runtime_state <- new.env(parent = emptyenv())
.sparx_runtime_state$abort_requested <- FALSE
.sparx_runtime_state$input_tokens <- 0L
.sparx_runtime_state$output_tokens <- 0L

#' Request an abort of the currently-running agent turn
#' @keywords internal
sparx_request_abort <- function() {
  .sparx_runtime_state$abort_requested <- TRUE
}

#' Clear the abort flag
#' @keywords internal
sparx_clear_abort <- function() {
  .sparx_runtime_state$abort_requested <- FALSE
}

#' Check whether abort has been requested
#' @keywords internal
sparx_abort_requested <- function() {
  isTRUE(.sparx_runtime_state$abort_requested)
}

#' Reset cumulative token counters
#' @keywords internal
sparx_reset_tokens <- function() {
  .sparx_runtime_state$input_tokens <- 0L
  .sparx_runtime_state$output_tokens <- 0L
}

#' Convert a tool result string into Anthropic-format content payload
#'
#' Most tool results are plain text, but some (inspect_plot) embed a special
#' image marker. This function splits such results into a mixed content
#' array of text + image blocks so Claude's vision can see attached images.
#'
#' @return Either a character string (for plain text) OR a list of content
#'   blocks (if any images were found)
#' @keywords internal
tool_result_to_content <- function(result) {
  if (is.null(result) || !is.character(result) || length(result) != 1) {
    return(as.character(result))
  }

  # Find SPARX_IMAGE markers
  pattern <- "<<<SPARX_IMAGE ([a-z]+)>>>\\s*\\n([A-Za-z0-9+/=\\s]+?)\\s*\\n<<<END SPARX_IMAGE>>>"
  match_info <- regmatches(result, regexec(pattern, result, perl = TRUE))[[1]]

  if (length(match_info) < 3) {
    # No image marker — plain text result
    return(result)
  }

  # Build a mixed content array
  # (Anthropic accepts content as either a string OR an array of blocks)
  media_type <- paste0("image/", match_info[2])
  image_data <- gsub("\\s", "", match_info[3])  # strip any whitespace from base64

  # Text before + after the image
  full_match <- match_info[1]
  match_start <- regexpr(pattern, result, perl = TRUE)
  match_len <- attr(match_start, "match.length")

  before <- trimws(substring(result, 1, match_start - 1))
  after <- trimws(substring(result, match_start + match_len))

  blocks <- list()
  if (nchar(before) > 0) {
    blocks[[length(blocks) + 1]] <- list(type = "text", text = before)
  }
  blocks[[length(blocks) + 1]] <- list(
    type = "image",
    source = list(
      type = "base64",
      media_type = media_type,
      data = image_data
    )
  )
  if (nchar(after) > 0) {
    blocks[[length(blocks) + 1]] <- list(type = "text", text = after)
  }
  if (length(blocks) == 1 && blocks[[1]]$type == "image") {
    # Anthropic requires tool_result to have non-empty text content
    # alongside images; add a minimal caption.
    blocks[[length(blocks) + 1]] <- list(type = "text", text = "(plot captured)")
  }

  blocks
}

#' Check whether a tool result looks like an error
#' @keywords internal
is_tool_error <- function(result) {
  if (is.null(result)) return(FALSE)
  s <- as.character(result)
  # Heuristic: starts with "ERROR:" or contains explicit error markers
  grepl("^ERROR:|^ERROR executing|\\bError in\\b", s, perl = TRUE)
}

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

  sparx_clear_abort()

  for (iter in seq_len(MAX_AGENT_ITERATIONS)) {
    if (sparx_abort_requested()) {
      return(list(
        messages = messages,
        final_text = "(stopped by user)",
        iterations = iter - 1,
        aborted = TRUE
      ))
    }
    on_iteration(iter)

    response <- call_claude_streaming(
      system_prompt = system_prompt,
      messages = messages,
      tools = tools,
      on_text_chunk = on_text_chunk,
      on_tool_start = on_tool_start,
      max_tokens = 2048
    )

    # Accumulate token usage
    if (!is.null(response$usage)) {
      if (!is.na(response$usage$input_tokens %||% NA)) {
        .sparx_runtime_state$input_tokens <-
          .sparx_runtime_state$input_tokens + response$usage$input_tokens
      }
      if (!is.na(response$usage$output_tokens %||% NA)) {
        .sparx_runtime_state$output_tokens <-
          .sparx_runtime_state$output_tokens + response$usage$output_tokens
      }
    }

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
      if (sparx_abort_requested()) {
        result <- "ABORTED: user requested stop before this tool ran."
        err <- TRUE
      } else {
        result <- execute_tool(call$name, call$input)
        err <- is_tool_error(result)
      }
      on_tool_result(call$name, call$id, result)

      # Check for embedded image payload (from inspect_plot)
      content_payload <- tool_result_to_content(result)

      tool_results[[length(tool_results) + 1]] <- list(
        type = "tool_result",
        tool_use_id = call$id,
        content = content_payload,
        is_error = err
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
