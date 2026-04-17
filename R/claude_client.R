#' Claude API client — streaming SSE
#'
#' This module talks directly to api.anthropic.com/v1/messages.
#' Uses BYOK (Bring Your Own Key) model — the user's key is stored in the
#' system keyring and loaded on each request.
#'
#' For a managed mode (our proxy), see claude_client_proxy.R (v1.1).

ANTHROPIC_API_URL <- "https://api.anthropic.com/v1/messages"
ANTHROPIC_VERSION <- "2023-06-01"

#' Call Claude with streaming response
#'
#' Streams tokens from Claude via Server-Sent Events. Calls `on_chunk` for
#' each text delta, and returns the complete response text + token usage at
#' the end.
#'
#' @param system_prompt Character. The system instruction.
#' @param messages List of message objects (role/content pairs).
#' @param on_chunk Function called with each streamed text chunk.
#' @param model Optional model override.
#' @param max_tokens Maximum tokens to generate.
#'
#' @return A list with fields: text (full response), input_tokens, output_tokens
#'
#' @keywords internal
call_claude_streaming <- function(system_prompt,
                                  messages,
                                  on_chunk = function(chunk) invisible(),
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

  accumulated <- character()
  usage <- list(input_tokens = NA_integer_, output_tokens = NA_integer_)

  req <- httr2::request(ANTHROPIC_API_URL) |>
    httr2::req_headers(
      `x-api-key` = api_key,
      `anthropic-version` = ANTHROPIC_VERSION,
      `content-type` = "application/json"
    ) |>
    httr2::req_body_json(body) |>
    httr2::req_timeout(120)

  httr2::req_perform_stream(req, callback = function(chunk_bytes) {
    chunk <- rawToChar(chunk_bytes)
    # SSE chunks arrive as "data: {...}\n\n"
    lines <- strsplit(chunk, "\n", fixed = TRUE)[[1]]
    for (line in lines) {
      if (!startsWith(line, "data: ")) next
      payload_str <- substring(line, 7)
      if (payload_str == "[DONE]") next

      parsed <- tryCatch(
        jsonlite::fromJSON(payload_str, simplifyVector = FALSE),
        error = function(e) NULL
      )
      if (is.null(parsed)) next

      if (!is.null(parsed$type)) {
        if (parsed$type == "content_block_delta") {
          delta_text <- parsed$delta$text %||% ""
          if (nchar(delta_text) > 0) {
            accumulated <<- c(accumulated, delta_text)
            on_chunk(delta_text)
          }
        } else if (parsed$type == "message_delta") {
          if (!is.null(parsed$usage$output_tokens)) {
            usage$output_tokens <<- parsed$usage$output_tokens
          }
        } else if (parsed$type == "message_start") {
          if (!is.null(parsed$message$usage$input_tokens)) {
            usage$input_tokens <<- parsed$message$usage$input_tokens
          }
        }
      }
    }
    TRUE  # Keep streaming
  }, buffer_kb = 8)

  list(
    text = paste(accumulated, collapse = ""),
    input_tokens = usage$input_tokens,
    output_tokens = usage$output_tokens
  )
}

#' Extract R code blocks from a Claude response
#'
#' @param text The full response text
#' @return Character vector of code block contents
#'
#' @keywords internal
extract_code_blocks <- function(text) {
  # Match ```r ... ``` or ``` ... ```
  matches <- regmatches(
    text,
    gregexpr("```(?:r|R)?\\s*\\n([\\s\\S]*?)```", text, perl = TRUE)
  )[[1]]

  if (length(matches) == 0) return(character())

  # Strip the fences
  cleaned <- gsub("^```(?:r|R)?\\s*\\n|```$", "", matches, perl = TRUE)
  trimws(cleaned)
}
