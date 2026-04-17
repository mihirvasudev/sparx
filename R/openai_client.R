#' OpenAI API client — streaming SSE with tool-use (function-calling) support
#'
#' Implements the same `call_provider_streaming()` contract as the Anthropic
#' client (in claude_client.R). Internally handles:
#' - Converting our internal (Anthropic-format) message list to OpenAI's
#'   chat-completions format
#' - Converting tool definitions from Anthropic schema (input_schema) to
#'   OpenAI schema (parameters wrapped in function object)
#' - Parsing OpenAI's streaming SSE (chat.completion.chunk events) to
#'   reconstruct text + tool_calls

OPENAI_API_URL <- "https://api.openai.com/v1/chat/completions"

#' Convert an Anthropic-format tool definition to OpenAI function-tool format
#' @keywords internal
convert_tool_to_openai <- function(tool) {
  list(
    type = "function",
    `function` = list(
      name = tool$name,
      description = tool$description,
      parameters = tool$input_schema
    )
  )
}

#' Convert the internal (Anthropic-format) messages list to OpenAI format
#'
#' Anthropic shape:
#'   { role:"user",       content: "string" }                      // user turn
#'   { role:"user",       content: [{type:"tool_result", ...}] }   // tool results
#'   { role:"assistant",  content: [{type:"text",...}, {type:"tool_use",...}] }
#'
#' OpenAI shape:
#'   { role:"user",       content: "..." }
#'   { role:"assistant",  content: "...", tool_calls: [{id, type:"function", function:{name,arguments}}] }
#'   { role:"tool",       tool_call_id: "...", content: "..." }
#'
#' @keywords internal
convert_messages_to_openai <- function(messages) {
  out <- list()
  for (msg in messages) {
    role <- msg$role
    content <- msg$content

    if (role == "user") {
      # Could be plain-text user turn OR tool-result continuation
      if (is.character(content) && length(content) == 1) {
        out[[length(out) + 1]] <- list(role = "user", content = content)
      } else if (is.list(content)) {
        for (block in content) {
          if (identical(block$type, "tool_result")) {
            out[[length(out) + 1]] <- list(
              role = "tool",
              tool_call_id = block$tool_use_id,
              content = as.character(block$content %||% "")
            )
          } else if (identical(block$type, "text")) {
            out[[length(out) + 1]] <- list(role = "user", content = block$text)
          }
        }
      }
    } else if (role == "assistant") {
      text_parts <- character()
      tool_calls <- list()
      if (is.list(content)) {
        for (block in content) {
          if (identical(block$type, "text")) {
            text_parts <- c(text_parts, block$text %||% "")
          } else if (identical(block$type, "tool_use")) {
            tool_calls[[length(tool_calls) + 1]] <- list(
              id = block$id,
              type = "function",
              `function` = list(
                name = block$name,
                # OpenAI expects arguments as a JSON string
                arguments = jsonlite::toJSON(block$input %||% list(),
                                             auto_unbox = TRUE)
              )
            )
          }
        }
      } else if (is.character(content)) {
        text_parts <- content
      }

      msg_out <- list(role = "assistant")
      text_merged <- paste(text_parts, collapse = "")
      if (nchar(text_merged) > 0) msg_out$content <- text_merged else msg_out$content <- ""
      if (length(tool_calls) > 0) msg_out$tool_calls <- tool_calls
      out[[length(out) + 1]] <- msg_out
    }
  }
  out
}

#' Call OpenAI with streaming (matches the Anthropic client contract)
#'
#' @return List with `content` (Anthropic-format blocks for uniform consumption),
#'   `stop_reason`, `usage`.
#' @keywords internal
call_openai_streaming <- function(system_prompt,
                                  messages,
                                  tools = NULL,
                                  on_text_chunk = function(chunk) invisible(),
                                  on_tool_start = function(name, id) invisible(),
                                  model = NULL,
                                  max_tokens = 2048) {
  api_key <- get_api_key("openai")
  if (is.null(api_key) || nchar(api_key) == 0) {
    stop(
      "No OpenAI API key found. Run `sparx::set_api_key(provider = \"openai\")` ",
      "to set one, or set the OPENAI_API_KEY environment variable."
    )
  }

  if (is.null(model)) model <- get_model("openai")

  # Prepend system message (OpenAI wants system as first message)
  openai_messages <- c(
    list(list(role = "system", content = system_prompt)),
    convert_messages_to_openai(messages)
  )

  body <- list(
    model = model,
    messages = openai_messages,
    max_tokens = max_tokens,
    stream = TRUE,
    stream_options = list(include_usage = TRUE)
  )
  if (!is.null(tools) && length(tools) > 0) {
    body$tools <- lapply(tools, convert_tool_to_openai)
  }

  # Accumulators (closure-captured — we use a shared env to avoid <<- issues)
  state <- new.env(parent = emptyenv())
  state$text <- character()
  state$tool_calls <- list()         # keyed by index: list(id, name, args_json_chunks)
  state$finish_reason <- NA_character_
  state$usage <- list(input_tokens = NA_integer_, output_tokens = NA_integer_)
  state$line_buffer <- ""
  state$tool_seen_index <- integer()  # which indices have triggered on_tool_start

  # Disable cli ANSI colors — otherwise httr2's progress output leaks
  # terminal escape codes into the Shiny gadget
  old_cli <- options(cli.num_colors = 1L, cli.hyperlink = FALSE)
  on.exit(options(old_cli), add = TRUE)

  req <- httr2::request(OPENAI_API_URL) |>
    httr2::req_headers(
      Authorization = paste("Bearer", api_key),
      `content-type` = "application/json"
    ) |>
    httr2::req_body_json(body) |>
    httr2::req_timeout(120) |>
    httr2::req_retry(
      max_tries = 4,
      is_transient = function(resp) {
        httr2::resp_status(resp) %in% c(429, 500, 502, 503, 504)
      },
      backoff = function(attempt) min(60, 5 * (3 ^ (attempt - 1)))
    )

  process_event <- function(payload_str) {
    if (payload_str == "" || payload_str == "[DONE]") return(invisible())
    parsed <- tryCatch(
      jsonlite::fromJSON(payload_str, simplifyVector = FALSE),
      error = function(e) NULL
    )
    if (is.null(parsed)) return(invisible())

    # Usage info (sent in final chunk when stream_options.include_usage=true)
    if (!is.null(parsed$usage)) {
      if (!is.null(parsed$usage$prompt_tokens)) {
        state$usage$input_tokens <- parsed$usage$prompt_tokens
      }
      if (!is.null(parsed$usage$completion_tokens)) {
        state$usage$output_tokens <- parsed$usage$completion_tokens
      }
    }

    choices <- parsed$choices
    if (is.null(choices) || length(choices) == 0) return(invisible())

    ch <- choices[[1]]
    delta <- ch$delta

    # Text content
    if (!is.null(delta$content) && nchar(delta$content) > 0) {
      state$text <- c(state$text, delta$content)
      on_text_chunk(delta$content)
    }

    # Tool call deltas — arrive as partial chunks with an index
    if (!is.null(delta$tool_calls) && length(delta$tool_calls) > 0) {
      for (tc_delta in delta$tool_calls) {
        idx <- as.character((tc_delta$index %||% 0) + 1)  # 1-based
        if (is.null(state$tool_calls[[idx]])) {
          state$tool_calls[[idx]] <- list(
            id = NULL, name = NULL, args_chunks = character()
          )
        }
        if (!is.null(tc_delta$id)) {
          state$tool_calls[[idx]]$id <- tc_delta$id
        }
        if (!is.null(tc_delta$`function`$name)) {
          state$tool_calls[[idx]]$name <- tc_delta$`function`$name
        }
        if (!is.null(tc_delta$`function`$arguments)) {
          state$tool_calls[[idx]]$args_chunks <- c(
            state$tool_calls[[idx]]$args_chunks,
            tc_delta$`function`$arguments
          )
        }
        # Notify UI once we have both id and name
        tc <- state$tool_calls[[idx]]
        if (!is.null(tc$id) && !is.null(tc$name) &&
            !(idx %in% state$tool_seen_index)) {
          state$tool_seen_index <- c(state$tool_seen_index, idx)
          on_tool_start(tc$name, tc$id)
        }
      }
    }

    if (!is.null(ch$finish_reason) && !is.na(ch$finish_reason)) {
      state$finish_reason <- ch$finish_reason
    }
  }

  httr2::req_perform_stream(req, callback = function(chunk_bytes) {
    text <- rawToChar(chunk_bytes)
    state$line_buffer <- paste0(state$line_buffer, text)

    pieces <- strsplit(state$line_buffer, "\n", fixed = TRUE)[[1]]
    if (!endsWith(state$line_buffer, "\n")) {
      state$line_buffer <- pieces[length(pieces)]
      pieces <- pieces[-length(pieces)]
    } else {
      state$line_buffer <- ""
    }

    for (line in pieces) {
      if (startsWith(line, "data: ")) {
        process_event(substring(line, 7))
      }
    }
    TRUE
  }, buffer_kb = 4)

  # Reassemble into Anthropic-format content blocks for uniform downstream use
  content <- list()
  text_all <- paste(state$text, collapse = "")
  if (nchar(text_all) > 0) {
    content[[length(content) + 1]] <- list(type = "text", text = text_all)
  }
  # Tool calls — parse the accumulated JSON arguments
  for (idx in names(state$tool_calls)) {
    tc <- state$tool_calls[[idx]]
    args_json <- paste(tc$args_chunks, collapse = "")
    parsed_input <- tryCatch(
      jsonlite::fromJSON(if (nchar(args_json) > 0) args_json else "{}",
                         simplifyVector = FALSE),
      error = function(e) list()
    )
    content[[length(content) + 1]] <- list(
      type = "tool_use",
      id = tc$id,
      name = tc$name,
      input = parsed_input
    )
  }

  # Map OpenAI finish_reason to Anthropic-ish stop_reason for consistency
  stop_reason <- switch(
    state$finish_reason %||% "",
    "tool_calls" = "tool_use",
    "stop" = "end_turn",
    "length" = "max_tokens",
    state$finish_reason %||% NA_character_
  )

  list(
    content = content,
    stop_reason = stop_reason,
    usage = state$usage
  )
}
