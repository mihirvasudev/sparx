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
    overflow-x: hidden;
    padding: 14px 16px;
    background: #fafafa;
    scroll-behavior: smooth;
  }
  .sparx-welcome {
    padding: 20px 16px;
    text-align: left;
    color: #6b7280;
    font-size: 13px;
    line-height: 1.6;
  }
  .sparx-welcome h3 {
    color: #111827;
    margin: 0 0 10px 0;
    font-size: 15px;
    font-weight: 600;
  }
  .sparx-welcome ul {
    text-align: left;
    margin: 10px 0 0 0;
    padding-left: 18px;
  }
  .sparx-welcome li {
    margin: 4px 0;
  }
  .sparx-bubble {
    margin-bottom: 10px;
    padding: 9px 13px;
    border-radius: 10px;
    max-width: 100%;
    word-wrap: break-word;
    line-height: 1.55;
    font-size: 13px;
  }
  .sparx-user {
    background: #2563eb;
    color: white;
    margin-left: 15%;
    box-shadow: 0 1px 2px rgba(0,0,0,0.05);
  }
  .sparx-assistant {
    background: white;
    color: #111827;
    border: 1px solid #e5e7eb;
    margin-right: 5%;
    box-shadow: 0 1px 2px rgba(0,0,0,0.03);
  }
  .sparx-assistant pre {
    background: #0f172a;
    color: #e2e8f0;
    padding: 10px 12px;
    border-radius: 6px;
    overflow-x: auto;
    margin: 8px 0 6px 0;
    font-size: 12px;
    font-family: 'SF Mono', Monaco, Consolas, monospace;
    line-height: 1.5;
  }
  .sparx-assistant code:not(pre code) {
    background: #f3f4f6;
    padding: 1px 5px;
    border-radius: 3px;
    font-size: 12px;
    font-family: 'SF Mono', Monaco, Consolas, monospace;
    color: #1e40af;
  }
  .sparx-code-actions {
    display: flex;
    gap: 4px;
    margin: 4px 0 0 0;
  }
  .sparx-code-actions button {
    background: white;
    border: 1px solid #d1d5db;
    color: #4b5563;
    padding: 3px 10px;
    border-radius: 4px;
    font-size: 11px;
    cursor: pointer;
    font-weight: 500;
    transition: all 0.15s;
  }
  .sparx-code-actions button:hover {
    background: #eef2ff;
    border-color: #a5b4fc;
    color: #3730a3;
  }
  .sparx-code-actions button.sparx-run {
    background: #10b981;
    border-color: #10b981;
    color: white;
  }
  .sparx-code-actions button.sparx-run:hover {
    background: #059669;
    border-color: #059669;
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

  /* Controls bar — single compact row */
  .sparx-controls {
    display: flex;
    align-items: center;
    gap: 4px;
    padding: 4px 10px;
    border-bottom: 1px solid #e5e7eb;
    background: #f9fafb;
    font-size: 10px;
    flex-wrap: nowrap;
    overflow: hidden;
    min-height: 28px;
  }
  .sparx-mode-label {
    color: #9ca3af;
    font-weight: 500;
    font-size: 9px;
    text-transform: uppercase;
    letter-spacing: 0.3px;
    flex-shrink: 0;
  }
  .sparx-toggle {
    padding: 1px 6px !important;
    font-size: 9px !important;
    line-height: 1.3 !important;
    background: white !important;
    border: 1px solid #d1d5db !important;
    border-radius: 3px !important;
    color: #6b7280 !important;
    height: 18px !important;
    margin: 0 !important;
    white-space: nowrap;
    flex-shrink: 0;
  }
  .sparx-toggle:hover {
    background: #eef2ff !important;
    color: #4338ca !important;
    border-color: #c7d2fe !important;
  }
  .sparx-usage {
    margin-left: auto;
    color: #9ca3af;
    font-family: 'SF Mono', Monaco, monospace;
    font-size: 9px;
    flex-shrink: 0;
    white-space: nowrap;
  }
  .sparx-separator {
    color: #e5e7eb;
    margin: 0 2px;
    flex-shrink: 0;
  }
  /* Provider dropdown — tight inline with toggles */
  .sparx-controls .form-group {
    margin: 0 !important;
    display: inline-block;
    flex-shrink: 0;
  }
  .sparx-controls select.form-control {
    height: 18px !important;
    padding: 0 18px 0 5px !important;
    font-size: 9px !important;
    line-height: 1.3 !important;
    background-color: white !important;
    border-color: #d1d5db !important;
    border-radius: 3px !important;
    min-width: 130px !important;
  }
  .sparx-send-group {
    display: flex;
    gap: 6px;
    align-items: center;
  }
  .sparx-stop {
    display: none !important;
  }
  .sparx-streaming .sparx-stop {
    display: inline-block !important;
  }
  .sparx-streaming #send {
    display: none !important;
  }

  /* Diff view */
  .sparx-diff {
    margin-top: 6px;
    padding: 6px 8px;
    background: #f9fafb;
    border: 1px solid #e5e7eb;
    border-radius: 3px;
    font-family: 'SF Mono', Monaco, monospace;
    font-size: 11px;
    max-height: 200px;
    overflow: auto;
    white-space: pre;
  }
  .sparx-diff-line-add {
    color: #065f46;
    background: #d1fae5;
    display: block;
  }
  .sparx-diff-line-del {
    color: #991b1b;
    background: #fee2e2;
    display: block;
  }

  /* Image preview */
  .sparx-image-preview {
    margin-top: 6px;
    max-width: 100%;
  }
  .sparx-image-preview img {
    max-width: 100%;
    max-height: 280px;
    border-radius: 4px;
    border: 1px solid #e5e7eb;
  }

  /* Todo list */
  .sparx-todos {
    margin: 10px 0;
    padding: 10px 12px;
    background: #fefce8;
    border-left: 3px solid #eab308;
    border-radius: 4px;
  }
  .sparx-todos-header {
    font-weight: 600;
    font-size: 11px;
    color: #78350f;
    margin-bottom: 6px;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
  .sparx-todo-item {
    font-size: 12px;
    padding: 2px 0;
    display: flex;
    gap: 6px;
    align-items: flex-start;
  }
  .sparx-todo-item.done {
    color: #6b7280;
    text-decoration: line-through;
  }
  .sparx-todo-item.active {
    font-weight: 600;
    color: #92400e;
  }
  .sparx-todo-marker {
    font-family: monospace;
    flex-shrink: 0;
    width: 14px;
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
#'
#' Parses special markers in the result:
#' - <<<DIFF>>>...<<<END DIFF>>>            → colored +/- diff view
#' - <<<SPARX_IMAGE png>>>...<<<END ...>>>  → inline image preview
#' @keywords internal
render_tool_result <- function(tool_name, result) {
  result_text <- if (is.null(result)) "" else as.character(result)

  # Special rendering for edit_file diff
  diff_match <- regmatches(
    result_text,
    regexec("<<<DIFF>>>\\s*\\n([\\s\\S]*?)\\n<<<END DIFF>>>", result_text, perl = TRUE)
  )[[1]]

  if (length(diff_match) >= 2) {
    diff_content <- diff_match[2]
    prose <- trimws(sub("<<<DIFF>>>[\\s\\S]*<<<END DIFF>>>", "", result_text, perl = TRUE))
    return(shiny::div(
      class = "sparx-tool",
      shiny::span(class = "sparx-tool-icon", "\u2713"),
      shiny::div(
        class = "sparx-tool-body",
        shiny::div(class = "sparx-tool-name", pretty_tool_name(tool_name)),
        shiny::div(class = "sparx-tool-result", prose),
        render_diff_block(diff_content)
      )
    ))
  }

  # Special rendering for captured plot
  img_match <- regmatches(
    result_text,
    regexec("<<<SPARX_IMAGE ([a-z]+)>>>\\s*\\n([A-Za-z0-9+/=\\s]+?)\\s*\\n<<<END SPARX_IMAGE>>>",
            result_text, perl = TRUE)
  )[[1]]

  if (length(img_match) >= 3) {
    media_type <- paste0("image/", img_match[2])
    img_data <- gsub("\\s", "", img_match[3])
    return(shiny::div(
      class = "sparx-tool",
      shiny::span(class = "sparx-tool-icon", "\u2713"),
      shiny::div(
        class = "sparx-tool-body",
        shiny::div(class = "sparx-tool-name", pretty_tool_name(tool_name)),
        shiny::div(
          class = "sparx-image-preview",
          shiny::HTML(paste0(
            '<img src="data:', media_type, ';base64,', img_data,
            '" alt="Plot captured by sparx" />'
          ))
        )
      )
    ))
  }

  # Default: plain text
  display_text <- if (nchar(result_text) > 1200) {
    paste0(substr(result_text, 1, 1200), "\n\n... [truncated in UI — Claude saw full output]")
  } else {
    result_text
  }

  shiny::div(
    class = "sparx-tool",
    shiny::span(class = "sparx-tool-icon", "\u2713"),
    shiny::div(
      class = "sparx-tool-body",
      shiny::div(class = "sparx-tool-name", pretty_tool_name(tool_name)),
      shiny::div(class = "sparx-tool-result", display_text)
    )
  )
}

#' Render a +/- diff block with color highlighting
#' @keywords internal
render_diff_block <- function(diff_text) {
  lines <- strsplit(diff_text, "\n", fixed = TRUE)[[1]]
  rendered <- lapply(lines, function(l) {
    if (startsWith(l, "+ ")) {
      shiny::HTML(paste0(
        '<span class="sparx-diff-line-add">+ ',
        escape_html(substring(l, 3)), '</span>'
      ))
    } else if (startsWith(l, "- ")) {
      shiny::HTML(paste0(
        '<span class="sparx-diff-line-del">- ',
        escape_html(substring(l, 3)), '</span>'
      ))
    } else {
      shiny::HTML(paste0('<span>', escape_html(l), '</span>'))
    }
  })
  shiny::div(class = "sparx-diff", shiny::tagList(rendered))
}

#' Render the current todo list (from .sparx_todo_state)
#' @keywords internal
render_todo_list <- function(todos) {
  if (length(todos) == 0) return(NULL)

  items <- lapply(todos, function(t) {
    status <- t$status %||% "pending"
    cls <- paste0("sparx-todo-item ",
                  switch(status,
                         "completed" = "done",
                         "in_progress" = "active",
                         ""))
    marker <- switch(status,
                     "completed" = "[x]",
                     "in_progress" = "[>]",
                     "[ ]")
    shiny::div(
      class = cls,
      shiny::span(class = "sparx-todo-marker", marker),
      shiny::span(t$content %||% "")
    )
  })

  shiny::div(
    class = "sparx-todos",
    shiny::div(class = "sparx-todos-header", "Tasks"),
    shiny::tagList(items)
  )
}

#' Human-friendly name for a tool
#' @keywords internal
pretty_tool_name <- function(name) {
  labels <- c(
    inspect_data = "Inspecting data",
    run_r_preview = "Running R code (preview)",
    check_package = "Checking package",
    read_editor = "Reading editor",
    list_files = "Listing files",
    read_file = "Reading file",
    grep_files = "Searching files",
    write_file = "Writing file",
    edit_file = "Editing file",
    inspect_plot = "Looking at the plot",
    install_packages = "Installing packages",
    todo_write = "Updating task list",
    run_in_session = "Running in live session",
    get_session_state = "Checking session state",
    fetch_url = "Fetching web page",
    git_status = "Checking git status",
    git_diff = "Reading git diff",
    git_log = "Reading git log",
    git_commit = "Creating git commit"
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

  // Toggle Send/Stop visibility based on streaming state
  if (window.Shiny && Shiny.addCustomMessageHandler) {
    Shiny.addCustomMessageHandler('sparx_set_streaming', function(streaming) {
      document.body.classList.toggle('sparx-streaming', !!streaming);
    });
  }

  // Auto-scroll thread on update, but ONLY when user is already near the bottom.
  // If they've scrolled up to read earlier content, leave them alone.
  var sparxLastScrollCheck = 0;
  setInterval(function() {
    var t = document.getElementById('sparx-thread');
    if (!t) return;
    var distanceFromBottom = t.scrollHeight - t.scrollTop - t.clientHeight;
    if (distanceFromBottom < 80) t.scrollTop = t.scrollHeight;
  }, 400);
  "
}
