#' UI render helpers — bubbles, tool cards, diff blocks, images, todos
#'
#' These functions produce the Shiny tags used by the chat gadget.
#' The look-and-feel is driven entirely by ui.R's CSS tokens.

# ── Shared JavaScript ──────────────────────────────────────────────────────

#' Client-side JS glue (sent once with the UI)
#'
#' - Cmd+Enter to send
#' - sparxSendCode / sparxCopyCode globals for per-code-block buttons
#' - Toggle body.sparx-streaming via Shiny custom message
#' - Tool-card expand/collapse
#' - Slash-command menu (v0.9)
#' - Conditional auto-scroll (only when user is near bottom)
#' - Auto-grow textarea
#'
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
    // Escape: abort streaming if running
    if (e.key === 'Escape') {
      var stop = document.getElementById('stop');
      if (stop && stop.offsetParent !== null) {
        stop.click();
        e.preventDefault();
      }
    }
  });

  // Insert/Run/Copy handlers for generated code blocks
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
    // Flash the button
    var btn = event.currentTarget;
    var orig = btn.textContent;
    btn.textContent = 'Copied';
    setTimeout(function() { btn.textContent = orig; }, 1200);
  };

  // Streaming state toggle (body class drives Send/Stop visibility)
  if (window.Shiny && Shiny.addCustomMessageHandler) {
    Shiny.addCustomMessageHandler('sparx_set_streaming', function(streaming) {
      document.body.classList.toggle('sparx-streaming', !!streaming);
    });
    Shiny.addCustomMessageHandler('sparx_highlight', function(_) {
      if (typeof Prism !== 'undefined') Prism.highlightAll();
    });
  }

  // Tool card expand / collapse
  document.addEventListener('click', function(e) {
    var summary = e.target.closest('.sparx-tool-summary');
    if (summary) {
      summary.parentElement.classList.toggle('expanded');
    }
    // Starter prompt clicked: fill input and focus
    var starter = e.target.closest('.sparx-starter');
    if (starter) {
      var text = starter.getAttribute('data-prompt');
      var ta = document.querySelector('.sparx-input-area textarea');
      if (ta) {
        ta.value = text;
        ta.focus();
        ta.dispatchEvent(new Event('input', { bubbles: true }));
      }
    }
  });

  // Conditional auto-scroll — only when user is within 80px of the bottom
  setInterval(function() {
    var t = document.getElementById('sparx-thread');
    if (!t) return;
    var gap = t.scrollHeight - t.scrollTop - t.clientHeight;
    if (gap < 80) t.scrollTop = t.scrollHeight;
  }, 400);

  // Auto-grow textarea + slash-command menu
  var SLASH_COMMANDS = [
    { cmd: '/clear',    desc: 'Clear the conversation' },
    { cmd: '/model',    desc: 'Switch model (e.g. /model haiku)' },
    { cmd: '/provider', desc: 'Switch provider (anthropic | openai)' },
    { cmd: '/retry',    desc: 'Retry the last message' },
    { cmd: '/help',     desc: 'Show sparx help' }
  ];

  document.addEventListener('input', function(e) {
    var ta = e.target;
    if (!ta.matches('.sparx-input-area textarea')) return;
    // Auto-grow
    ta.style.height = 'auto';
    ta.style.height = Math.min(ta.scrollHeight, 160) + 'px';
    // Slash-command detection
    var menu = document.getElementById('sparx-slash-menu');
    if (!menu) return;
    if (ta.value.startsWith('/')) {
      var query = ta.value.split(/\\s/)[0];
      var matches = SLASH_COMMANDS.filter(function(c) {
        return c.cmd.indexOf(query) === 0;
      });
      if (matches.length > 0) {
        menu.innerHTML = matches.map(function(m) {
          return '<div class=\"sparx-slash-item\" data-cmd=\"' + m.cmd + '\">' +
                 '<span class=\"sparx-slash-cmd\">' + m.cmd + '</span>' +
                 '<span class=\"sparx-slash-desc\">' + m.desc + '</span></div>';
        }).join('');
        menu.classList.add('active');
      } else {
        menu.classList.remove('active');
      }
    } else {
      menu.classList.remove('active');
    }
  });

  // Pick a slash command
  document.addEventListener('click', function(e) {
    var item = e.target.closest('.sparx-slash-item');
    if (!item) return;
    var ta = document.querySelector('.sparx-input-area textarea');
    if (ta) {
      var cmd = item.getAttribute('data-cmd');
      ta.value = cmd + ' ';
      ta.focus();
      ta.dispatchEvent(new Event('input', { bubbles: true }));
    }
    document.getElementById('sparx-slash-menu').classList.remove('active');
  });

  // Up-arrow in empty input recalls last user message (Shell-style)
  document.addEventListener('keydown', function(e) {
    if (e.key !== 'ArrowUp') return;
    var ta = e.target;
    if (!ta.matches('.sparx-input-area textarea')) return;
    if (ta.value.length === 0) {
      // Find the last user bubble
      var bubbles = document.querySelectorAll('.sparx-user');
      if (bubbles.length > 0) {
        var last = bubbles[bubbles.length - 1];
        ta.value = last.textContent.trim();
        ta.dispatchEvent(new Event('input', { bubbles: true }));
        e.preventDefault();
      }
    }
  });
  "
}

# ── Welcome / empty state ──────────────────────────────────────────────────

#' Session-aware welcome card with clickable starter prompts + key-setup fallback
#'
#' Reads the user's .GlobalEnv and tailors starter prompts to loaded data.
#' If no provider is configured, pivots to a setup guide.
#' @keywords internal
welcome_message_html <- function() {
  configured <- tryCatch(configured_providers(), error = function(e) character())

  # No API key configured at all — show setup guide, not starters
  if (length(configured) == 0) {
    return(shiny::HTML(paste0(
      '<h3>Welcome to sparx</h3>',
      '<div class="sparx-welcome-intro">',
      "Let\u2019s get you set up. You need an API key for <strong>one</strong> ",
      "provider to start:",
      '</div>',
      '<div style="margin: 10px 0; font-size: 12px; line-height: 1.7;">',
      '<strong>Anthropic (Claude)</strong> \u2014 ',
      'get a key at <a href="https://console.anthropic.com" target="_blank">console.anthropic.com</a>, then in the R Console:',
      '<pre style="margin: 4px 0; padding: 6px 10px;"><code>sparx::set_api_key()</code></pre>',
      '<strong>OpenAI (GPT)</strong> \u2014 ',
      'get a key at <a href="https://platform.openai.com/api-keys" target="_blank">platform.openai.com/api-keys</a>, then:',
      '<pre style="margin: 4px 0; padding: 6px 10px;"><code>sparx::set_api_key(provider = "openai")</code></pre>',
      '</div>',
      privacy_note_html(),
      '<div style="margin-top: 12px; font-size: 11px; color: var(--sparx-color-text-muted);">',
      "After saving your key, close this panel (top-right Close button) and reopen via <strong>Addins \u2192 Open sparx Chat</strong>.",
      '</div>'
    )))
  }

  # Detect dataframes for session-aware starters
  dfs <- list_dataframes()
  df_names <- names(dfs)

  intro <- if (length(df_names) == 0) {
    paste0(
      "I don\u2019t see any dataframes loaded yet. Load some data and ask me ",
      "a question \u2014 I'll handle the rest."
    )
  } else if (length(df_names) == 1) {
    df <- dfs[[df_names[1]]]
    sprintf("I see you have <code>%s</code> loaded (%d rows \u00d7 %d cols). Ready when you are.",
            escape_html(df_names[1]), df$rows, df$cols)
  } else {
    summaries <- sapply(df_names[1:min(3, length(df_names))], function(n) {
      sprintf("<code>%s</code> (%d\u00d7%d)",
              escape_html(n), dfs[[n]]$rows, dfs[[n]]$cols)
    })
    sprintf("You have %d dataframes loaded: %s.",
            length(df_names), paste(summaries, collapse = ", "))
  }

  # Build starter prompts
  starters <- character()
  if (length(df_names) > 0) {
    main_df <- df_names[1]
    starters <- c(starters,
      sprintf("Summarize %s and flag anything unusual.", main_df),
      sprintf("Suggest the most informative analysis for %s.", main_df)
    )
    cols <- dfs[[main_df]]$columns
    types <- vapply(cols, function(c) c$type, character(1))
    numeric_cols <- vapply(cols, function(c) c$name, character(1))[grepl("numeric|integer", types)]
    factor_cols <- vapply(cols, function(c) c$name, character(1))[grepl("factor|character", types)]
    if (length(numeric_cols) > 0 && length(factor_cols) > 0) {
      starters <- c(starters,
        sprintf("Compare %s across %s groups in %s, check assumptions, pick the right test.",
                numeric_cols[1], factor_cols[1], main_df))
    }
  } else {
    starters <- c(
      "Load mtcars into df and help me explore it.",
      "Which statistical test should I use for comparing two independent groups?",
      "Walk me through a typical clinical-research analysis workflow in R."
    )
  }

  starter_html <- paste(
    sprintf(
      '<button class="sparx-starter" data-prompt="%s">%s</button>',
      escape_html(starters), escape_html(starters)
    ),
    collapse = ""
  )

  shiny::HTML(paste0(
    '<h3>sparx</h3>',
    '<div class="sparx-welcome-intro">', intro, '</div>',
    starter_html,
    privacy_note_html()
  ))
}

#' Short privacy note shown at bottom of welcome card
#' @keywords internal
privacy_note_html <- function() {
  paste0(
    '<div style="margin-top: 16px; padding: 8px 10px; background: var(--sparx-color-bg-muted); ',
    'border-left: 2px solid var(--sparx-color-text-subtle); font-size: 10px; color: var(--sparx-color-text-muted); line-height: 1.5;">',
    '<strong>Privacy:</strong> your prompts, code, and dataframe <em>schemas</em> ',
    '(column names + types, not row data) are sent to the model provider. ',
    '<strong>Do not use sparx with PHI/PII unless your institution has a BAA</strong> ',
    'with Anthropic or OpenAI.',
    '</div>'
  )
}

# ── Message bubbles ────────────────────────────────────────────────────────

#' Render a user message bubble
#' @keywords internal
render_user_bubble <- function(text) {
  shiny::div(
    class = "sparx-bubble sparx-user",
    shiny::HTML(escape_html(text))
  )
}

#' Render an assistant message using CommonMark-based markdown
#'
#' Also extracts code blocks and wraps them in sparx-codeblock containers
#' with language + actions (Insert / Run preview / Copy).
#' @keywords internal
render_assistant_bubble <- function(text, streaming = FALSE) {
  if (is.null(text) || length(text) == 0) text <- ""

  # Parse the message into alternating prose / code sections (so we can
  # wrap each code block in our own action-bearing container)
  parts <- parse_message_parts(text)

  rendered <- lapply(parts, function(p) {
    if (p$type == "code") {
      code_block_with_actions(p$content, p$lang)
    } else {
      shiny::HTML(render_markdown(p$content))
    }
  })

  if (streaming) {
    rendered <- c(rendered, list(shiny::HTML('<span class="sparx-streaming-cursor"></span>')))
  }

  shiny::div(
    class = "sparx-assistant sparx-markdown",
    shiny::div(
      class = "sparx-sender",
      shiny::HTML('<span class="sparx-sender-dot"></span>sparx')
    ),
    shiny::tagList(rendered)
  )
}

# ── Markdown rendering ─────────────────────────────────────────────────────

#' Render markdown text to safe HTML
#'
#' Uses the commonmark package for CommonMark-compliant parsing, then
#' strips any embedded script tags as a belt-and-braces safety measure.
#'
#' @keywords internal
render_markdown <- function(text) {
  if (is.null(text) || length(text) == 0 || !nzchar(text)) return("")
  html <- tryCatch(
    commonmark::markdown_html(text, smart = TRUE, extensions = c("table", "autolink")),
    error = function(e) paste0("<p>", escape_html(text), "</p>")
  )
  # Strip <script> tags as a safety measure (CommonMark doesn't emit them,
  # but raw HTML in the input could pass through)
  html <- gsub("<script[^>]*>.*?</script>", "", html, ignore.case = TRUE, perl = TRUE)
  html
}

#' Parse a message into alternating prose / code sections
#'
#' Returns a list where each element is either
#'   { type = "prose", content = "..." } or
#'   { type = "code", content = "...", lang = "r" }.
#' @keywords internal
parse_message_parts <- function(text) {
  pattern <- "```([a-zA-Z0-9_+-]*)[ \\t]*\\n([\\s\\S]*?)```"
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

    if (match_start > cursor) {
      prose <- substr(text, cursor, match_start - 1)
      if (nchar(trimws(prose)) > 0) {
        parts <- c(parts, list(list(type = "prose", content = prose)))
      }
    }

    lang_start <- capture[i, 1]
    lang_len <- capture_len[i, 1]
    lang <- if (lang_len > 0) substr(text, lang_start, lang_start + lang_len - 1) else "r"
    if (lang == "") lang <- "r"

    code_start <- capture[i, 2]
    code_len <- capture_len[i, 2]
    code <- substr(text, code_start, code_start + code_len - 1)
    parts <- c(parts, list(list(type = "code", content = trimws(code), lang = tolower(lang))))

    cursor <- match_end + 1
  }

  if (cursor <= nchar(text)) {
    tail <- substr(text, cursor, nchar(text))
    if (nchar(trimws(tail)) > 0) {
      parts <- c(parts, list(list(type = "prose", content = tail)))
    }
  }

  parts
}

# ── Code blocks with actions ───────────────────────────────────────────────

#' Render a code block with header (language + line count), actions,
#' and Prism-compatible `language-r` class for syntax highlighting.
#'
#' @keywords internal
code_block_with_actions <- function(code, lang = "r") {
  code_id <- paste0("sparx-code-", sample.int(1e9, 1))
  lang_norm <- if (lang %in% c("r", "python", "sql", "markdown", "md")) lang else "r"
  n_lines <- length(strsplit(code, "\n", fixed = TRUE)[[1]])

  shiny::HTML(paste0(
    '<div class="sparx-codeblock">',
      '<div class="sparx-codeblock-header">',
        '<span>',
          '<span class="sparx-codeblock-lang">', lang_norm, '</span>',
          '<span class="sparx-codeblock-meta"> \u00b7 ', n_lines, ' line', if (n_lines != 1) 's' else '', '</span>',
        '</span>',
        '<button class="sparx-codeblock-copy" onclick="sparxCopyCode(\'', code_id, '\')">Copy</button>',
      '</div>',
      '<pre><code id="', code_id, '" class="language-', lang_norm, '">',
        escape_html(code),
      '</code></pre>',
      '<div class="sparx-code-actions">',
        '<button onclick="sparxSendCode(\'insert_code\', \'', code_id, '\')">Insert</button>',
        '<button class="sparx-run" onclick="sparxSendCode(\'run_code\', \'', code_id, '\')">&#9654; Run</button>',
      '</div>',
    '</div>'
  ))
}

# ── Tool cards (collapsible) ───────────────────────────────────────────────

#' Render an active (running) tool card
#' @keywords internal
render_tool_badge <- function(tool_name, input_preview = NULL, running = TRUE) {
  cls <- if (running) "sparx-tool running" else "sparx-tool"
  shiny::HTML(paste0(
    '<div class="', cls, '">',
      '<div class="sparx-tool-summary">',
        '<span class="sparx-tool-chevron">&#9656;</span>',
        '<span class="sparx-tool-icon">&gt;_</span>',
        '<span class="sparx-tool-name">', escape_html(pretty_tool_name(tool_name)), '</span>',
        '<span class="sparx-tool-input">',
          escape_html(input_preview %||% ""),
        '</span>',
        '<span class="sparx-tool-status">running</span>',
      '</div>',
    '</div>'
  ))
}

#' Render a completed tool call with collapsible details
#'
#' Summary row: chevron, icon, tool name, concise input preview, status.
#' Click to expand the full result.
#' @keywords internal
render_tool_result <- function(tool_name, result, input = NULL) {
  result_text <- if (is.null(result)) "" else as.character(result)

  # Special rendering: edit_file diff
  diff_match <- regmatches(
    result_text,
    regexec("<<<DIFF>>>\\s*\\n([\\s\\S]*?)\\n<<<END DIFF>>>", result_text, perl = TRUE)
  )[[1]]

  # Special rendering: captured plot image
  img_match <- regmatches(
    result_text,
    regexec("<<<SPARX_IMAGE ([a-z]+)>>>\\s*\\n([A-Za-z0-9+/=\\s]+?)\\s*\\n<<<END SPARX_IMAGE>>>",
            result_text, perl = TRUE)
  )[[1]]

  # Build summary parts
  is_error <- grepl("^ERROR", result_text) || grepl("^ABORTED", result_text)
  status_label <- extract_status_label(tool_name, result_text, is_error)
  input_preview <- extract_input_preview(tool_name, input)
  icon <- if (is_error) "!" else "\u2713"
  status_class <- if (is_error) "err" else "ok"

  # Build details payload
  details <- if (length(diff_match) >= 2) {
    diff_content <- diff_match[2]
    prose <- trimws(sub("<<<DIFF>>>[\\s\\S]*<<<END DIFF>>>", "", result_text, perl = TRUE))
    shiny::tagList(
      if (nchar(prose) > 0) shiny::tags$pre(prose),
      render_diff_block(diff_content)
    )
  } else if (length(img_match) >= 3) {
    media_type <- paste0("image/", img_match[2])
    img_data <- gsub("\\s", "", img_match[3])
    shiny::div(
      class = "sparx-image-preview",
      shiny::HTML(paste0('<img src="data:', media_type, ';base64,', img_data,
                         '" alt="Plot captured by sparx" />'))
    )
  } else {
    display_text <- if (nchar(result_text) > 3000) {
      paste0(substr(result_text, 1, 3000),
             "\n\n... [truncated in UI \u2014 Claude saw full output]")
    } else {
      result_text
    }
    shiny::tags$pre(display_text)
  }

  shiny::HTML(paste0(
    '<div class="sparx-tool">',
      '<div class="sparx-tool-summary">',
        '<span class="sparx-tool-chevron">&#9656;</span>',
        '<span class="sparx-tool-icon">', icon, '</span>',
        '<span class="sparx-tool-name">', escape_html(pretty_tool_name(tool_name)), '</span>',
        '<span class="sparx-tool-input">', escape_html(input_preview), '</span>',
        '<span class="sparx-tool-status ', status_class, '">', escape_html(status_label), '</span>',
      '</div>',
      '<div class="sparx-tool-details">',
        as.character(details),
      '</div>',
    '</div>'
  ))
}

#' Extract a short input preview for the tool summary row
#' @keywords internal
extract_input_preview <- function(tool_name, input) {
  if (is.null(input) || length(input) == 0) return("")
  preview <- switch(
    tool_name,
    "inspect_data"   = input$name %||% "",
    "run_r_preview"  = truncate_str(input$code %||% "", 60),
    "run_in_session" = truncate_str(input$code %||% "", 60),
    "check_package"  = input$package %||% "",
    "read_file"      = input$path %||% "",
    "read_editor"    = paste0("lines ", input$line_start %||% "?", "-", input$line_end %||% "end"),
    "list_files"     = input$pattern %||% "*",
    "grep_files"     = truncate_str(input$pattern %||% "", 40),
    "write_file"     = input$path %||% "",
    "edit_file"      = input$path %||% "",
    "fetch_url"      = truncate_str(input$url %||% "", 50),
    "install_packages" = paste(unlist(input$packages), collapse = ", "),
    "git_diff"       = input$path %||% "(all)",
    "git_commit"     = truncate_str(input$message %||% "", 50),
    ""
  )
  if (is.null(preview)) "" else as.character(preview)
}

#' Extract a concise status label for the tool summary row
#' @keywords internal
extract_status_label <- function(tool_name, result, is_error) {
  if (is_error) {
    return(truncate_str(sub("^ERROR:?\\s*", "", sub("\\n.*", "", result)), 40))
  }
  # Tool-specific concise labels
  dims <- regmatches(result, regexpr("\\d+\\s*rows?\\s*x\\s*\\d+\\s*col", result, perl = TRUE))
  if (length(dims) > 0 && dims != "") return(gsub("\\s+", "", dims))
  n_matched <- regmatches(result, regexpr("Found \\d+ matches", result, perl = TRUE))
  if (length(n_matched) > 0 && n_matched != "") return(n_matched)
  if (startsWith(result, "Successfully")) return("ok")
  if (nchar(result) < 40) return(trimws(result))
  "done"
}

#' Truncate a string with ellipsis
#' @keywords internal
truncate_str <- function(x, n = 60) {
  if (is.null(x) || nchar(x) <= n) return(x %||% "")
  paste0(substr(x, 1, n - 1), "\u2026")
}

# ── Diff block (colored +/- lines) ─────────────────────────────────────────

#' @keywords internal
render_diff_block <- function(diff_text) {
  lines <- strsplit(diff_text, "\n", fixed = TRUE)[[1]]
  rendered <- lapply(lines, function(l) {
    if (startsWith(l, "+ ")) {
      shiny::HTML(paste0('<span class="sparx-diff-line-add">+ ',
                         escape_html(substring(l, 3)), '</span>'))
    } else if (startsWith(l, "- ")) {
      shiny::HTML(paste0('<span class="sparx-diff-line-del">- ',
                         escape_html(substring(l, 3)), '</span>'))
    } else {
      shiny::HTML(paste0('<span>', escape_html(l), '</span>'))
    }
  })
  shiny::div(class = "sparx-diff", shiny::tagList(rendered))
}

# ── Todo list card ─────────────────────────────────────────────────────────

#' @keywords internal
render_todo_list <- function(todos) {
  if (length(todos) == 0) return(NULL)
  items <- lapply(todos, function(t) {
    status <- t$status %||% "pending"
    cls <- paste0("sparx-todo-item ",
                  switch(status, "completed" = "done", "in_progress" = "active", ""))
    marker <- switch(status, "completed" = "[x]", "in_progress" = "[>]", "[ ]")
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

# ── Tool-name prettifier ───────────────────────────────────────────────────

#' @keywords internal
pretty_tool_name <- function(name) {
  labels <- c(
    inspect_data       = "inspect data",
    run_r_preview      = "run preview",
    check_package      = "check package",
    read_editor        = "read editor",
    list_files         = "list files",
    read_file          = "read file",
    grep_files         = "grep",
    write_file         = "write file",
    edit_file          = "edit file",
    inspect_plot       = "inspect plot",
    install_packages   = "install packages",
    todo_write         = "update tasks",
    run_in_session     = "run live",
    get_session_state  = "session state",
    fetch_url          = "fetch url",
    git_status         = "git status",
    git_diff           = "git diff",
    git_log            = "git log",
    git_commit         = "git commit"
  )
  lbl <- labels[name]
  if (is.na(lbl)) name else unname(lbl)
}

# ── HTML escape ────────────────────────────────────────────────────────────

#' @keywords internal
escape_html <- function(text) {
  if (is.null(text)) return("")
  text <- gsub("&", "&amp;", text, fixed = TRUE)
  text <- gsub("<", "&lt;", text, fixed = TRUE)
  text <- gsub(">", "&gt;", text, fixed = TRUE)
  text
}
