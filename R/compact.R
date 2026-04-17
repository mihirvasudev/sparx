#' Context compaction — summarize earlier conversation to stay under the
#' model's context window.
#'
#' When input_tokens on the last API call exceeds a threshold, we ask the
#' same model to summarize the earlier turns into a compact paragraph,
#' then replace those turns with the summary. The last N user turns are
#' kept verbatim so immediate context isn't lost.
#'
#' Safety: we only compact at turn boundaries (before a new user message
#' kicks off an agent turn), never mid-loop — that would break the
#' Anthropic tool_use/tool_result pairing requirement.

#' Default token threshold before auto-compaction.
#' Most models have a 128K-200K context window; compacting at 100K leaves
#' plenty of headroom for the next turn's system prompt + response.
#' Override with `options(sparx.compact_threshold = ...)`.
#' @keywords internal
COMPACT_DEFAULT_THRESHOLD <- 100000L

#' Number of recent user-turn pairs to preserve untouched.
#' @keywords internal
COMPACT_KEEP_RECENT <- 2L

#' Should we compact before the next API call?
#' @keywords internal
should_compact <- function() {
  threshold <- as.integer(getOption("sparx.compact_threshold",
                                    COMPACT_DEFAULT_THRESHOLD))
  last_in <- .sparx_runtime_state$last_input_tokens %||% 0L
  last_in >= threshold
}

#' Compact a message history by summarizing older turns
#'
#' @param messages Anthropic-format messages list
#' @param keep_recent Number of recent user turns to preserve (default 2)
#' @param on_notice Function called with a status string (for UI updates)
#'
#' @return Compacted messages list, or original list if nothing to compact
#' @keywords internal
compact_conversation <- function(messages,
                                 keep_recent = COMPACT_KEEP_RECENT,
                                 on_notice = function(msg) invisible()) {
  n <- length(messages)
  if (n < 4) return(messages)  # nothing meaningful to summarize

  # Find user-turn indices
  user_indices <- which(vapply(messages, function(m) identical(m$role, "user") &&
                                 is.character(m$content) && length(m$content) == 1,
                               logical(1)))
  if (length(user_indices) <= keep_recent) return(messages)

  # Split at: everything before the (keep_recent)-th-from-last user message
  split_point <- user_indices[length(user_indices) - keep_recent + 1]
  to_summarize <- messages[seq_len(split_point - 1)]
  to_keep <- messages[seq(split_point, n)]

  if (length(to_summarize) == 0) return(messages)

  on_notice("Compacting earlier conversation...")

  # Build a transcript summary prompt
  transcript <- format_messages_for_summary(to_summarize)

  summary_response <- tryCatch(
    call_provider_streaming(
      system_prompt = paste(
        "You are a conversation summarizer. Given a transcript of an AI",
        "coding-assistant session, produce a compact summary (<=500 words)",
        "that preserves:",
        "- The user's original goal(s)",
        "- Key decisions made",
        "- Tools called and their essential outcomes (not raw output)",
        "- Open questions or unresolved issues",
        "- Final state of any files / dataframes the agent touched",
        "Drop: verbose tool output, redundant rephrasings, pleasantries.",
        "Format: markdown. Start with '## Prior conversation summary'.",
        sep = "\n"
      ),
      messages = list(list(role = "user", content = transcript)),
      tools = NULL,
      max_tokens = 1024
    ),
    error = function(e) NULL
  )

  if (is.null(summary_response)) {
    on_notice("Compaction failed, continuing with full context.")
    return(messages)
  }

  # Extract text from the response
  summary_text <- paste(
    vapply(summary_response$content, function(b) {
      if (identical(b$type, "text")) b$text else ""
    }, character(1)),
    collapse = ""
  )
  if (!nzchar(summary_text)) return(messages)

  on_notice(sprintf("Compacted %d earlier messages into a summary.",
                    length(to_summarize)))

  # Build new compacted prefix (faux user+assistant pair so the model sees
  # a natural handoff, without messing with tool-use/tool-result pairing)
  c(
    list(
      list(role = "user",
           content = paste0("[Earlier conversation summarized to save context]\n\n",
                            summary_text)),
      list(role = "assistant",
           content = "Got it — continuing from here with compacted context.")
    ),
    to_keep
  )
}

#' Convert a messages list into a readable transcript for summarization
#'
#' @keywords internal
format_messages_for_summary <- function(messages) {
  lines <- character()
  for (msg in messages) {
    role <- msg$role
    content <- msg$content

    if (role == "user") {
      if (is.character(content) && length(content) == 1) {
        lines <- c(lines, paste0("USER: ", truncate_str(content, 800)))
      } else if (is.list(content)) {
        for (block in content) {
          if (identical(block$type, "tool_result")) {
            result_text <- as.character(block$content %||% "")
            lines <- c(lines,
                       paste0("TOOL_RESULT [", block$tool_use_id, "]: ",
                              truncate_str(result_text, 400)))
          }
        }
      }
    } else if (role == "assistant") {
      if (is.list(content)) {
        for (block in content) {
          type <- block$type %||% "text"
          if (type == "text" && !is.null(block$text)) {
            lines <- c(lines, paste0("ASSISTANT: ",
                                     truncate_str(block$text, 800)))
          } else if (type == "tool_use") {
            args_str <- tryCatch(
              jsonlite::toJSON(block$input %||% list(), auto_unbox = TRUE),
              error = function(e) "{}"
            )
            lines <- c(lines, paste0("TOOL_CALL [", block$name, " / ",
                                     block$id, "]: ",
                                     truncate_str(as.character(args_str), 300)))
          }
        }
      } else if (is.character(content)) {
        lines <- c(lines, paste0("ASSISTANT: ", truncate_str(content, 800)))
      }
    }
  }
  paste(lines, collapse = "\n\n")
}
