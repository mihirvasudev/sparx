#' UI render helpers — premium redesign (v1.2.0)
#'
#' No assistant bubble (plain prose).
#' User bubble: right-aligned pill.
#' Tool row: minimal horizontal with chevron + colored icon + status dot.
#' Code block: 8px rounded, hover-revealed copy, warm-black background.

# ── Shared JavaScript ──────────────────────────────────────────────────────

#' Client-side JS glue (sent once with the UI)
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
  window.sparxCopyCode = function(codeId, btn) {
    var el = document.getElementById(codeId);
    if (!el) return;
    navigator.clipboard.writeText(el.textContent);
    if (btn) {
      var orig = btn.textContent;
      btn.textContent = 'Copied';
      setTimeout(function() { btn.textContent = orig; }, 1200);
    }
  };

  // Streaming state toggle (body class drives Send/Stop visibility)
  if (window.Shiny && Shiny.addCustomMessageHandler) {
    Shiny.addCustomMessageHandler('sparx_set_streaming', function(streaming) {
      document.body.classList.toggle('sparx-streaming', !!streaming);
    });
    Shiny.addCustomMessageHandler('sparx_highlight', function(_) {
      if (typeof Prism !== 'undefined') Prism.highlightAll();
    });
    Shiny.addCustomMessageHandler('sparx_set_toggle', function(data) {
      var btn = document.getElementById(data.id);
      if (!btn) return;
      var classes = ['sparx-toggle-plan','sparx-toggle-live','sparx-toggle-install','sparx-toggle-git'];
      btn.classList.toggle('sparx-toggle-on', !!data.on);
      classes.forEach(function(c) { btn.classList.remove(c); });
      btn.classList.add('sparx-toggle-' + data.name);
    });
  }

  // Tool card expand/collapse
  document.addEventListener('click', function(e) {
    var summary = e.target.closest('.sparx-tool-summary');
    if (summary) summary.parentElement.classList.toggle('expanded');

    // Starter prompt: fill input + focus
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

  // Conditional auto-scroll — only when user is near the bottom
  setInterval(function() {
    var t = document.getElementById('sparx-thread');
    if (!t) return;
    var gap = t.scrollHeight - t.scrollTop - t.clientHeight;
    if (gap < 100) t.scrollTop = t.scrollHeight;
  }, 400);

  // Scroll shadow on header
  var threadEl = null;
  var scrollObserverInterval = setInterval(function() {
    threadEl = document.getElementById('sparx-thread');
    if (!threadEl) return;
    var controls = document.querySelector('.sparx-controls');
    if (!controls) return;
    threadEl.addEventListener('scroll', function() {
      controls.classList.toggle('scrolled', threadEl.scrollTop > 10);
    });
    clearInterval(scrollObserverInterval);
  }, 400);

  // Auto-grow textarea + slash-command menu
  var SLASH_COMMANDS = [
    { cmd: '/clear',    desc: 'Clear the conversation' },
    { cmd: '/plan',     desc: 'Toggle plan mode (read-only exploration)' },
    { cmd: '/compact',  desc: 'Summarize earlier turns to save context' },
    { cmd: '/model',    desc: 'Switch model (haiku / sonnet / opus / 4o / mini)' },
    { cmd: '/provider', desc: 'Switch provider (anthropic / openai)' },
    { cmd: '/retry',    desc: 'Recall the last user message' },
    { cmd: '/help',     desc: 'Show slash-command help' }
  ];

  document.addEventListener('input', function(e) {
    var ta = e.target;
    if (!ta.matches('.sparx-input-area textarea')) return;
    ta.style.height = 'auto';
    ta.style.height = Math.min(ta.scrollHeight, 160) + 'px';
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

  // Up-arrow in empty input recalls last user message
  document.addEventListener('keydown', function(e) {
    if (e.key !== 'ArrowUp') return;
    var ta = e.target;
    if (!ta.matches('.sparx-input-area textarea')) return;
    if (ta.value.length === 0) {
      var bubbles = document.querySelectorAll('.sparx-user');
      if (bubbles.length > 0) {
        ta.value = bubbles[bubbles.length - 1].textContent.trim();
        ta.dispatchEvent(new Event('input', { bubbles: true }));
        e.preventDefault();
      }
    }
  });
  "
}

# ── Welcome / empty state ──────────────────────────────────────────────────

#' Session-aware welcome card
#' @keywords internal
welcome_message_html <- function() {
  configured <- tryCatch(configured_providers(), error = function(e) character())

  hero <- paste0(
    '<div class="sparx-welcome-hero">',
    '<span class="sparx-welcome-logo">\u2726</span>',
    '<div class="sparx-welcome-name">sparx</div>',
    '<div class="sparx-welcome-tagline">AI research partner for R</div>',
    '</div>'
  )

  # No key configured → setup cards
  if (length(configured) == 0) {
    return(shiny::HTML(paste0(
      hero,
      '<div class="sparx-welcome-intro">Let\u2019s get you set up. Choose a provider:</div>',

      '<div class="sparx-setup-card">',
      '<h4>Anthropic (Claude)</h4>',
      '<p>Get a key at <a href="https://console.anthropic.com" target="_blank">console.anthropic.com</a>, then paste this in the R Console:</p>',
      '<pre><code>sparx::set_api_key()</code></pre>',
      '</div>',

      '<div class="sparx-setup-card">',
      '<h4>OpenAI (GPT)</h4>',
      '<p>Get a key at <a href="https://platform.openai.com/api-keys" target="_blank">platform.openai.com/api-keys</a>:</p>',
      '<pre><code>sparx::set_api_key(provider = "openai")</code></pre>',
      '</div>',

      '<div class="sparx-privacy-note">',
      '<strong>Privacy:</strong> your prompts, code, and dataframe schemas ',
      '(column names + types, not row data) are sent to the chosen provider. ',
      'Do not use sparx with PHI/PII unless your institution has a BAA with them.',
      '</div>',

      '<div style="margin-top: 14px; font-size: 11px; color: var(--sparx-color-text-subtle); text-align: center;">',
      'After saving your key, close this panel and reopen via ',
      '<strong>Addins \u2192 Open sparx Chat</strong>.',
      '</div>'
    )))
  }

  # Session-aware intro
  dfs <- list_dataframes()
  df_names <- names(dfs)

  intro <- if (length(df_names) == 0) {
    "No dataframes loaded. Load some data (or try <code>sparx::demo_workflow()</code>) and I can help you analyze it."
  } else if (length(df_names) == 1) {
    df <- dfs[[df_names[1]]]
    sprintf("I see <code>%s</code> loaded (%d\u00d7%d). Ready when you are.",
            escape_html(df_names[1]), df$rows, df$cols)
  } else {
    summaries <- sapply(df_names[1:min(3, length(df_names))], function(n) {
      sprintf("<code>%s</code> (%d\u00d7%d)",
              escape_html(n), dfs[[n]]$rows, dfs[[n]]$cols)
    })
    sprintf("%d dataframes loaded: %s.",
            length(df_names), paste(summaries, collapse = ", "))
  }

  # Starter prompts
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
        sprintf("Compare %s across %s groups in %s \u2014 check assumptions, pick the right test.",
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
    hero,
    '<div class="sparx-welcome-intro">', intro, '</div>',
    starter_html,
    '<div class="sparx-privacy-note">',
    '<strong>Privacy:</strong> prompts, code, and dataframe schemas go to the model provider. ',
    'Avoid PHI/PII unless your institution has a BAA.',
    '</div>'
  ))
}

# ── System notice ──────────────────────────────────────────────────────────

#' Subtle inline banner (used for compaction, etc.)
#' @keywords internal
render_system_notice <- function(message) {
  shiny::HTML(paste0(
    '<div class="sparx-system-notice">',
    '<span class="sparx-system-notice-icon">\u2726</span>',
    '<span>', escape_html(message), '</span>',
    '</div>'
  ))
}

# ── Message bubbles ────────────────────────────────────────────────────────

#' User message — right-aligned pill
#' @keywords internal
render_user_bubble <- function(text) {
  shiny::HTML(paste0(
    '<div class="sparx-user-wrap">',
    '<div class="sparx-user">', escape_html(text), '</div>',
    '</div>'
  ))
}

#' Assistant message — no bubble, just clean prose with markdown
#' @keywords internal
render_assistant_bubble <- function(text, streaming = FALSE) {
  if (is.null(text) || length(text) == 0) text <- ""
  parts <- parse_message_parts(text)

  rendered <- lapply(parts, function(p) {
    if (p$type == "code") {
      code_block_with_actions(p$content, p$lang)
    } else {
      shiny::HTML(render_markdown(p$content))
    }
  })

  if (streaming) {
    rendered <- c(rendered,
                  list(shiny::HTML('<span class="sparx-streaming-cursor"></span>')))
  }

  shiny::div(
    class = "sparx-assistant sparx-markdown",
    shiny::tagList(rendered)
  )
}

# ── Markdown ───────────────────────────────────────────────────────────────

#' Render markdown to safe HTML
#' @keywords internal
render_markdown <- function(text) {
  if (is.null(text) || length(text) == 0 || !nzchar(text)) return("")
  html <- tryCatch(
    commonmark::markdown_html(text, smart = TRUE, extensions = c("table", "autolink")),
    error = function(e) paste0("<p>", escape_html(text), "</p>")
  )
  html <- gsub("<script[^>]*>.*?</script>", "", html, ignore.case = TRUE, perl = TRUE)
  html
}

#' Split a message into alternating prose / code sections
#' @keywords internal
parse_message_parts <- function(text) {
  pattern <- "```([a-zA-Z0-9_+-]*)[ \\t]*\\n([\\s\\S]*?)```"
  parts <- list()
  cursor <- 1
  matches <- gregexpr(pattern, text, perl = TRUE)[[1]]
  if (matches[1] == -1) return(list(list(type = "prose", content = text)))

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

# ── Code blocks ────────────────────────────────────────────────────────────

#' Render a code block with header (language + line count), actions,
#' Prism-compatible `language-r` class.
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
          '<span class="sparx-codeblock-meta">\u00b7 ', n_lines, ' line', if (n_lines != 1) 's' else '', '</span>',
        '</span>',
        '<button class="sparx-codeblock-copy" onclick="sparxCopyCode(\'', code_id, '\', this)">Copy</button>',
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

# ── Tool rows ──────────────────────────────────────────────────────────────

#' Tool category for color mapping
#' @keywords internal
tool_category <- function(name) {
  read_tools <- c("inspect_data", "check_package", "read_editor", "read_file",
                  "list_files", "grep_files", "get_session_state", "inspect_plot",
                  "read_console")
  write_tools <- c("write_file", "edit_file", "install_packages", "todo_write")
  run_tools <- c("run_r_preview", "run_in_session")
  git_tools <- c("git_status", "git_diff", "git_log", "git_commit")
  web_tools <- c("fetch_url")

  if (name %in% read_tools)  return("read")
  if (name %in% write_tools) return("write")
  if (name %in% run_tools)   return("run")
  if (name %in% git_tools)   return("git")
  if (name %in% web_tools)   return("web")
  "read"
}

#' Icon glyph for a tool category (monochrome, colored via CSS)
#' @keywords internal
tool_icon_glyph <- function(category) {
  switch(category,
    read  = "\u25a3",   # centered square (inspect)
    write = "\u270E",   # pencil
    run   = "\u25B6",   # play triangle
    git   = "\u2387",   # four-dot diamond
    web   = "\u2922",   # arrow
    "\u25CF"
  )
}

#' Render a tool badge (while running or on replay)
#' @keywords internal
render_tool_badge <- function(tool_name, input_preview = NULL, running = TRUE) {
  cat_name <- tool_category(tool_name)
  cls <- paste0("sparx-tool tool-cat-", cat_name, if (running) " running" else "")
  shiny::HTML(paste0(
    '<div class="', cls, '">',
      '<div class="sparx-tool-summary">',
        '<span class="sparx-tool-chevron">\u203a</span>',
        '<span class="sparx-tool-icon">', tool_icon_glyph(cat_name), '</span>',
        '<span class="sparx-tool-name">', escape_html(pretty_tool_name(tool_name)), '</span>',
        '<span class="sparx-tool-input">',
          escape_html(input_preview %||% ""),
        '</span>',
        '<span class="sparx-tool-dot"></span>',
        '<span class="sparx-tool-status">', if (running) "running" else "", '</span>',
      '</div>',
      '<div class="sparx-tool-details"><div class="sparx-tool-details-inner">',
        '<div class="sparx-tool-details-body"></div>',
      '</div></div>',
    '</div>'
  ))
}

#' Render a completed tool call, collapsible
#' @keywords internal
render_tool_result <- function(tool_name, result, input = NULL) {
  result_text <- if (is.null(result)) "" else as.character(result)

  diff_match <- regmatches(
    result_text,
    regexec("<<<DIFF>>>\\s*\\n([\\s\\S]*?)\\n<<<END DIFF>>>", result_text, perl = TRUE)
  )[[1]]

  img_match <- regmatches(
    result_text,
    regexec("<<<SPARX_IMAGE ([a-z]+)>>>\\s*\\n([A-Za-z0-9+/=\\s]+?)\\s*\\n<<<END SPARX_IMAGE>>>",
            result_text, perl = TRUE)
  )[[1]]

  is_error <- grepl("^ERROR", result_text) || grepl("^ABORTED", result_text) ||
              grepl("^REFUSED", result_text)
  status_label <- extract_status_label(tool_name, result_text, is_error)
  input_preview <- extract_input_preview(tool_name, input)
  cat_name <- tool_category(tool_name)

  state_cls <- if (is_error) " error" else ""
  cls <- paste0("sparx-tool tool-cat-", cat_name, state_cls)

  details_body <- if (length(diff_match) >= 2) {
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
             "\n\n... [truncated \u2014 Claude saw full output]")
    } else {
      result_text
    }
    shiny::tags$pre(display_text)
  }

  shiny::HTML(paste0(
    '<div class="', cls, '">',
      '<div class="sparx-tool-summary">',
        '<span class="sparx-tool-chevron">\u203a</span>',
        '<span class="sparx-tool-icon">', tool_icon_glyph(cat_name), '</span>',
        '<span class="sparx-tool-name">', escape_html(pretty_tool_name(tool_name)), '</span>',
        '<span class="sparx-tool-input">', escape_html(input_preview), '</span>',
        '<span class="sparx-tool-dot"></span>',
        '<span class="sparx-tool-status">', escape_html(status_label), '</span>',
      '</div>',
      '<div class="sparx-tool-details"><div class="sparx-tool-details-inner">',
        '<div class="sparx-tool-details-body">',
          as.character(details_body),
        '</div>',
      '</div></div>',
    '</div>'
  ))
}

#' Short input preview for tool summary row
#' @keywords internal
extract_input_preview <- function(tool_name, input) {
  if (is.null(input) || length(input) == 0) return("")
  preview <- switch(
    tool_name,
    "inspect_data"     = input$name %||% "",
    "run_r_preview"    = truncate_str(input$code %||% "", 60),
    "run_in_session"   = truncate_str(input$code %||% "", 60),
    "check_package"    = input$package %||% "",
    "read_file"        = input$path %||% "",
    "read_editor"      = paste0("lines ", input$line_start %||% "?", "-",
                                input$line_end %||% "end"),
    "list_files"       = input$pattern %||% "*",
    "grep_files"       = truncate_str(input$pattern %||% "", 40),
    "write_file"       = input$path %||% "",
    "edit_file"        = input$path %||% "",
    "fetch_url"        = truncate_str(input$url %||% "", 50),
    "install_packages" = paste(unlist(input$packages), collapse = ", "),
    "git_diff"         = input$path %||% "(all)",
    "git_commit"       = truncate_str(input$message %||% "", 50),
    ""
  )
  if (is.null(preview)) "" else as.character(preview)
}

#' Concise status label for tool summary row
#' @keywords internal
extract_status_label <- function(tool_name, result, is_error) {
  if (is_error) {
    first <- sub("\\n.*", "",
                 sub("^(ERROR:?|ABORTED:?|REFUSED:?)\\s*", "", result))
    return(truncate_str(first, 36))
  }
  dims <- regmatches(result, regexpr("\\d+\\s*rows?\\s*x\\s*\\d+\\s*col",
                                     result, perl = TRUE))
  if (length(dims) > 0 && dims != "") return(gsub("\\s+", "", dims))
  n_matched <- regmatches(result, regexpr("Found \\d+ matches",
                                          result, perl = TRUE))
  if (length(n_matched) > 0 && n_matched != "") return(n_matched)
  if (startsWith(result, "Successfully")) return("ok")
  if (nchar(result) < 36) return(trimws(result))
  "done"
}

#' Truncate with ellipsis
#' @keywords internal
truncate_str <- function(x, n = 60) {
  if (is.null(x) || nchar(x) <= n) return(x %||% "")
  paste0(substr(x, 1, n - 1), "\u2026")
}

# ── Diff block ─────────────────────────────────────────────────────────────

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

# ── Todo list ──────────────────────────────────────────────────────────────

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

# ── Pretty tool names ──────────────────────────────────────────────────────

#' @keywords internal
pretty_tool_name <- function(name) {
  labels <- c(
    inspect_data       = "inspect_data",
    run_r_preview      = "run_r_preview",
    check_package      = "check_package",
    read_editor        = "read_editor",
    list_files         = "list_files",
    read_file          = "read_file",
    grep_files         = "grep_files",
    write_file         = "write_file",
    edit_file          = "edit_file",
    inspect_plot       = "inspect_plot",
    install_packages   = "install_packages",
    todo_write         = "todo_write",
    run_in_session     = "run_in_session",
    get_session_state  = "get_session_state",
    fetch_url          = "fetch_url",
    git_status         = "git_status",
    git_diff           = "git_diff",
    git_log            = "git_log",
    git_commit         = "git_commit"
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
