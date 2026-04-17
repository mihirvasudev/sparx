#' UI helpers for the sparx chat gadget
#'
#' Renders message bubbles, code blocks, and action buttons.

#' CSS for the gadget
#' @keywords internal
chat_css <- function() {
  "
  .sparx-container {
    display: flex;
    flex-direction: column;
    height: 100%;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    font-size: 13px;
    color: #1f2937;
  }
  .sparx-thread {
    flex: 1;
    overflow-y: auto;
    padding: 12px;
    background: #f9fafb;
  }
  .sparx-welcome {
    padding: 24px;
    text-align: center;
    color: #6b7280;
  }
  .sparx-welcome h3 {
    color: #111827;
    margin-bottom: 8px;
  }
  .sparx-welcome ul {
    text-align: left;
    margin-top: 16px;
    padding-left: 20px;
  }
  .sparx-bubble {
    margin-bottom: 12px;
    padding: 10px 14px;
    border-radius: 10px;
    max-width: 100%;
    word-wrap: break-word;
    line-height: 1.5;
  }
  .sparx-user {
    background: #2563eb;
    color: white;
    margin-left: 20%;
  }
  .sparx-assistant {
    background: white;
    color: #111827;
    border: 1px solid #e5e7eb;
    margin-right: 10%;
  }
  .sparx-assistant pre {
    background: #1f2937;
    color: #f3f4f6;
    padding: 10px;
    border-radius: 6px;
    overflow-x: auto;
    margin: 8px 0;
    font-size: 12px;
    font-family: 'SF Mono', Monaco, Consolas, monospace;
  }
  .sparx-assistant code:not(pre code) {
    background: #f3f4f6;
    padding: 1px 4px;
    border-radius: 3px;
    font-size: 12px;
  }
  .sparx-code-actions {
    display: flex;
    gap: 6px;
    margin-top: 6px;
  }
  .sparx-code-actions button {
    background: #e0e7ff;
    border: 1px solid #c7d2fe;
    color: #3730a3;
    padding: 3px 10px;
    border-radius: 4px;
    font-size: 11px;
    cursor: pointer;
    font-weight: 500;
  }
  .sparx-code-actions button:hover {
    background: #c7d2fe;
  }
  .sparx-code-actions button.sparx-run {
    background: #d1fae5;
    border-color: #a7f3d0;
    color: #065f46;
  }
  .sparx-code-actions button.sparx-run:hover {
    background: #a7f3d0;
  }
  .sparx-streaming-cursor {
    display: inline-block;
    width: 6px;
    height: 13px;
    background: #2563eb;
    margin-left: 2px;
    animation: sparx-blink 1s step-end infinite;
    vertical-align: middle;
  }
  @keyframes sparx-blink {
    from, to { opacity: 1; }
    50% { opacity: 0; }
  }
  .sparx-input-area {
    padding: 10px;
    border-top: 1px solid #e5e7eb;
    background: white;
  }
  .sparx-input-actions {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-top: 6px;
  }
  .sparx-hint {
    font-size: 11px;
    color: #9ca3af;
  }

  /* Tool execution badges */
  .sparx-tool {
    display: flex;
    align-items: flex-start;
    gap: 8px;
    padding: 6px 10px;
    margin: 8px 0;
    border-left: 3px solid #8b5cf6;
    background: #faf5ff;
    border-radius: 4px;
    font-size: 12px;
    color: #5b21b6;
  }
  .sparx-tool-icon {
    font-family: 'SF Mono', Monaco, monospace;
    font-size: 11px;
    font-weight: 600;
    flex-shrink: 0;
  }
  .sparx-tool-body {
    flex: 1;
    min-width: 0;
  }
  .sparx-tool-name {
    font-weight: 600;
    margin-bottom: 2px;
  }
  .sparx-tool-result {
    margin-top: 4px;
    padding: 6px 8px;
    background: white;
    border: 1px solid #e9d5ff;
    border-radius: 3px;
    font-family: 'SF Mono', Monaco, monospace;
    font-size: 11px;
    color: #374151;
    max-height: 160px;
    overflow: auto;
    white-space: pre-wrap;
    word-break: break-word;
  }
  .sparx-tool-running .sparx-tool-name::after {
    content: ' ...';
    animation: sparx-blink 0.8s step-end infinite;
  }
  "
}

#' Welcome message shown before any messages
#' @keywords internal
welcome_message_html <- function() {
  shiny::HTML("
    <h3>sparx</h3>
    <p>AI pair-programmer for R. Ask me to:</p>
    <ul>
      <li>Write an analysis (\"fit a mixed model with hospitals as random\")</li>
      <li>Fix a bug (\"why is my code erroring?\")</li>
      <li>Explain code (select + right-click)</li>
      <li>Suggest a test (\"which test should I use for this data?\")</li>
    </ul>
  ")
}

#' Render a user message bubble
#' @keywords internal
render_user_bubble <- function(text) {
  shiny::div(
    class = "sparx-bubble sparx-user",
    shiny::HTML(escape_html(text))
  )
}

#' Render an assistant message bubble with code-action buttons
#' @keywords internal
render_assistant_bubble <- function(text, streaming = FALSE) {
  if (is.null(text) || length(text) == 0) text <- ""

  # Parse the message: split into prose + code blocks, render each
  parts <- parse_message_parts(text)
  rendered <- lapply(parts, function(p) {
    if (p$type == "code") {
      code_block_with_actions(p$content)
    } else {
      shiny::HTML(render_markdown_inline(p$content))
    }
  })

  if (streaming) {
    rendered <- c(rendered, list(shiny::HTML('<span class="sparx-streaming-cursor"></span>')))
  }

  shiny::div(
    class = "sparx-bubble sparx-assistant",
    shiny::tagList(rendered)
  )
}

#' Parse a message into alternating prose / code sections
#' @keywords internal
parse_message_parts <- function(text) {
  # Match triple-backtick code blocks
  pattern <- "```(?:r|R)?\\s*\\n([\\s\\S]*?)```"
  parts <- list()
  cursor <- 1
  matches <- gregexpr(pattern, text, perl = TRUE)[[1]]

  if (matches[1] == -1) {
    return(list(list(type = "prose", content = text)))
  }

  lengths <- attr(matches, "match.length")
  capture <- attr(matches, "capture.start")
  capture_len <- attr(matches, "capture.length")

  for (i in seq_along(matches)) {
    match_start <- matches[i]
    match_end <- match_start + lengths[i] - 1

    # Prose before this code block
    if (match_start > cursor) {
      prose <- substr(text, cursor, match_start - 1)
      if (nchar(trimws(prose)) > 0) {
        parts <- c(parts, list(list(type = "prose", content = prose)))
      }
    }

    # The code block itself
    code_start <- capture[i, 1]
    code_len <- capture_len[i, 1]
    code <- substr(text, code_start, code_start + code_len - 1)
    parts <- c(parts, list(list(type = "code", content = trimws(code))))

    cursor <- match_end + 1
  }

  # Trailing prose
  if (cursor <= nchar(text)) {
    tail <- substr(text, cursor, nchar(text))
    if (nchar(trimws(tail)) > 0) {
      parts <- c(parts, list(list(type = "prose", content = tail)))
    }
  }

  parts
}

#' Render a code block with Insert / Run / Copy buttons
#' @keywords internal
code_block_with_actions <- function(code) {
  code_id <- paste0("sparx-code-", sample.int(1e9, 1))
  shiny::tagList(
    shiny::HTML(paste0(
      '<pre><code id="', code_id, '">',
      escape_html(code),
      '</code></pre>'
    )),
    shiny::HTML(paste0(
      '<div class="sparx-code-actions">',
      '<button onclick="sparxSendCode(\'insert_code\', \'', code_id, '\')">Insert</button>',
      '<button class="sparx-run" onclick="sparxSendCode(\'run_code\', \'', code_id, '\')">Run</button>',
      '<button onclick="sparxCopyCode(\'', code_id, '\')">Copy</button>',
      '</div>'
    ))
  )
}

#' Very minimal inline markdown (bold, italic, inline code, newlines)
#' @keywords internal
render_markdown_inline <- function(text) {
  if (is.null(text) || length(text) == 0) return("")
  s <- escape_html(text)
  # Bold
  s <- gsub("\\*\\*([^*]+)\\*\\*", "<strong>\\1</strong>", s)
  # Inline code
  s <- gsub("`([^`]+)`", "<code>\\1</code>", s)
  # Italics (simple, avoids **bold** conflict)
  s <- gsub("(?<!\\*)\\*(?!\\*)([^*]+)(?<!\\*)\\*(?!\\*)", "<em>\\1</em>", s, perl = TRUE)
  # Newlines
  s <- gsub("\n", "<br>", s)
  s
}

#' Render an active (running) tool badge
#' @keywords internal
render_tool_badge <- function(tool_name, running = TRUE) {
  cls <- if (running) "sparx-tool sparx-tool-running" else "sparx-tool"
  shiny::div(
    class = cls,
    shiny::span(class = "sparx-tool-icon", ">_"),
    shiny::div(
      class = "sparx-tool-body",
      shiny::div(class = "sparx-tool-name", pretty_tool_name(tool_name))
    )
  )
}

#' Render a completed tool call with its result (collapsible)
#' @keywords internal
render_tool_result <- function(tool_name, result) {
  result_text <- if (is.null(result)) "" else as.character(result)
  # Truncate for display
  display_text <- if (nchar(result_text) > 1200) {
    paste0(substr(result_text, 1, 1200), "\n\n... [truncated in UI — Claude saw full output]")
  } else {
    result_text
  }

  shiny::div(
    class = "sparx-tool",
    shiny::span(class = "sparx-tool-icon", "✓"),
    shiny::div(
      class = "sparx-tool-body",
      shiny::div(class = "sparx-tool-name", pretty_tool_name(tool_name)),
      shiny::div(class = "sparx-tool-result", display_text)
    )
  )
}

#' Human-friendly name for a tool
#' @keywords internal
pretty_tool_name <- function(name) {
  labels <- c(
    inspect_data = "Inspecting data",
    run_r_preview = "Running R code (preview)",
    check_package = "Checking package",
    read_editor = "Reading editor"
  )
  lbl <- labels[name]
  if (is.na(lbl)) name else unname(lbl)
}

#' Escape HTML for safe rendering
#' @keywords internal
escape_html <- function(text) {
  if (is.null(text)) return("")
  text <- gsub("&", "&amp;", text, fixed = TRUE)
  text <- gsub("<", "&lt;", text, fixed = TRUE)
  text <- gsub(">", "&gt;", text, fixed = TRUE)
  text
}

#' JavaScript for Cmd+Enter to send + code-action routing
#' @keywords internal
cmd_enter_js <- function() {
  "
  // Cmd/Ctrl + Enter in the textarea triggers Send
  document.addEventListener('keydown', function(e) {
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
      var btn = document.getElementById('send');
      if (btn) btn.click();
      e.preventDefault();
    }
  });

  // When the user clicks Insert/Run on a code block, read the code text
  // and send it to Shiny as a custom input.
  window.sparxSendCode = function(inputName, codeId) {
    var el = document.getElementById(codeId);
    if (!el) return;
    var code = el.textContent;
    Shiny.setInputValue(inputName, code, { priority: 'event' });
  };

  window.sparxCopyCode = function(codeId) {
    var el = document.getElementById(codeId);
    if (!el) return;
    navigator.clipboard.writeText(el.textContent);
  };

  // Auto-scroll thread on update
  var thread = null;
  setInterval(function() {
    var t = document.getElementById('sparx-thread');
    if (t) t.scrollTop = t.scrollHeight;
  }, 500);
  "
}
