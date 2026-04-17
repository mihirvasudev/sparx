#' Claude API client — streaming SSE with tool-use support
#'
#' This module talks directly to api.anthropic.com/v1/messages. It handles:
#' - Streaming Server-Sent Events
#' - Text delta accumulation (for showing in chat UI)
#' - Tool-use block assembly (JSON chunks reconstructed across stream deltas)
#'
#' Returns a structured response containing text blocks AND any tool calls
#' the model wants to make. The agentic loop in agent.R uses this to iterate.

ANTHROPIC_API_URL <- "https://api.anthropic.com/v1/messages"
ANTHROPIC_VERSION <- "2023-06-01"

#' Call Claude with streaming — supports tool use
#'
#' @param system_prompt Character. System instruction.
#' @param messages List of message objects (role = user/assistant, content = ...)
#' @param tools Optional list of tool definitions (Anthropic schema)
#' @param on_text_chunk Called with each streamed text delta (for UI streaming)
#' @param on_tool_start Called when a tool_use block begins: fn(name, id)
#' @param model Optional model override
#' @param max_tokens Maximum tokens to generate
#'
#' @return A list with fields:
#'   - content: list of content blocks, each with type (text or tool_use)
#'     and the appropriate fields
#'   - stop_reason: "end_turn", "tool_use", "max_tokens", etc.
#'   - usage: input_tokens, output_tokens
#'
#' @keywords internal
call_claude_streaming <- function(system_prompt,
                                  messages,
                                  tools = NULL,
                                  on_text_chunk = function(chunk) invisible(),
                                  on_tool_start = function(name, id) invisible(),
                                  model = NULL,
                                  max_tokens = 2048) {
  api_key <- get_api_key()
  if (is.null(api_key) || nchar(api_key) == 0) {
    stop(
      "No Anthropic API key found. Run `sparx::set_api_key()` to set one, ",
      "or set the ANTHROPIC_API_KEY environment variable."
    )
  }

  if (is.null(model)) model <- get_model()

  body <- list(
    model = model,
    max_tokens = max_tokens,
    stream = TRUE,
    system = system_prompt,
    messages = messages
  )
  if (!is.null(tools) && length(tools) > 0) {
    body$tools <- tools
  }

  # State accumulated during streaming
  content_blocks <- list()  # final assembled blocks
  current_text <- character()  # text for the in-progress block
  current_tool_json <- character()  # JSON chunks for the in-progress tool_use block
  current_block_type <- NULL
  current_tool_name <- NULL
  current_tool_id <- NULL
  stop_reason <- NA_character_
  usage <- list(input_tokens = NA_integer_, output_tokens = NA_integer_)

  # Buffer for partial SSE lines across chunks
  line_buffer <- ""

  # Disable cli ANSI colors — otherwise httr2's progress output leaks
  # terminal escape codes into the Shiny gadget
  old_cli <- options(cli.num_colors = 1L, cli.hyperlink = FALSE)
  on.exit(options(old_cli), add = TRUE)

  req <- httr2::request(ANTHROPIC_API_URL) |>
    httr2::req_headers(
      `x-api-key` = api_key,
      `anthropic-version` = ANTHROPIC_VERSION,
      `content-type` = "application/json"
    ) |>
    httr2::req_body_json(body) |>
    httr2::req_timeout(120) |>
    httr2::req_retry(
      max_tries = 4,
      is_transient = function(resp) {
        httr2::resp_status(resp) %in% c(429, 500, 502, 503, 504)
      },
      # Use the Retry-After header if provided (Anthropic sets it on 429)
      # else exponential backoff: 5s, 15s, 30s, capped at 60s
      backoff = function(attempt) min(60, 5 * (3 ^ (attempt - 1))),
      after = function(resp) {
        retry_after <- tryCatch(
          httr2::resp_header(resp, "Retry-After"),
          error = function(e) NULL
        )
        if (!is.null(retry_after) && nzchar(retry_after)) {
          as.numeric(retry_after)
        } else {
          NULL  # fall through to backoff
        }
      }
    )

  process_event <- function(payload_str) {
    if (payload_str == "" || payload_str == "[DONE]") return(invisible())
    parsed <- tryCatch(
      jsonlite::fromJSON(payload_str, simplifyVector = FALSE),
      error = function(e) NULL
    )
    if (is.null(parsed) || is.null(parsed$type)) return(invisible())

    switch(
      parsed$type,
      "message_start" = {
        if (!is.null(parsed$message$usage$input_tokens)) {
          usage$input_tokens <<- parsed$message$usage$input_tokens
        }
      },
      "content_block_start" = {
        block <- parsed$content_block
        current_block_type <<- block$type
        if (block$type == "text") {
          current_text <<- character()
        } else if (block$type == "tool_use") {
          current_tool_json <<- character()
          current_tool_name <<- block$name
          current_tool_id <<- block$id
          on_tool_start(block$name, block$id)
        }
      },
      "content_block_delta" = {
        delta <- parsed$delta
        if (!is.null(delta$type)) {
          if (delta$type == "text_delta" && !is.null(delta$text)) {
            current_text <<- c(current_text, delta$text)
            on_text_chunk(delta$text)
          } else if (delta$type == "input_json_delta" && !is.null(delta$partial_json)) {
            current_tool_json <<- c(current_tool_json, delta$partial_json)
          }
        }
      },
      "content_block_stop" = {
        if (isTRUE(current_block_type == "text")) {
          content_blocks[[length(content_blocks) + 1]] <<- list(
            type = "text",
            text = paste(current_text, collapse = "")
          )
        } else if (isTRUE(current_block_type == "tool_use")) {
          json_str <- paste(current_tool_json, collapse = "")
          parsed_input <- tryCatch(
            jsonlite::fromJSON(if (nchar(json_str) > 0) json_str else "{}",
                               simplifyVector = FALSE),
            error = function(e) list()
          )
          content_blocks[[length(content_blocks) + 1]] <<- list(
            type = "tool_use",
            id = current_tool_id,
            name = current_tool_name,
            input = parsed_input
          )
        }
        current_block_type <<- NULL
        current_tool_name <<- NULL
        current_tool_id <<- NULL
      },
      "message_delta" = {
        if (!is.null(parsed$delta$stop_reason)) {
          stop_reason <<- parsed$delta$stop_reason
        }
        if (!is.null(parsed$usage$output_tokens)) {
          usage$output_tokens <<- parsed$usage$output_tokens
        }
      },
      "message_stop" = invisible(),
      invisible()
    )
  }

  httr2::req_perform_stream(req, callback = function(chunk_bytes) {
    text <- rawToChar(chunk_bytes)
    line_buffer <<- paste0(line_buffer, text)

    # Split on newline; keep the trailing partial line for next chunk
    pieces <- strsplit(line_buffer, "\n", fixed = TRUE)[[1]]
    if (!endsWith(line_buffer, "\n")) {
      line_buffer <<- pieces[length(pieces)]
      pieces <- pieces[-length(pieces)]
    } else {
      line_buffer <<- ""
    }

    for (line in pieces) {
      if (startsWith(line, "data: ")) {
        process_event(substring(line, 7))
      }
    }
    TRUE  # continue streaming
  }, buffer_kb = 4)

  list(
    content = content_blocks,
    stop_reason = stop_reason,
    usage = usage
  )
}
