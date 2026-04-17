#' Open the sparx chat gadget
#'
#' Primary entry point for the addin. Opens a miniUI gadget in RStudio's
#' viewer pane with the full agentic pipeline wired up.
#'
#' @export
open_chat <- function() {
  if (!requireNamespace("shiny", quietly = TRUE) ||
      !requireNamespace("miniUI", quietly = TRUE)) {
    stop("sparx requires `shiny` and `miniUI`. Install with install.packages(c('shiny', 'miniUI')).")
  }

  # Need at least one provider configured
  configured <- configured_providers()
  if (length(configured) == 0) {
    if (interactive()) {
      message("sparx: no API key configured. Let's set one up for ",
              provider_info()$name, ".")
      set_api_key()
    } else {
      stop("Run sparx::set_api_key() first.")
    }
  } else if (!(get_provider() %in% configured)) {
    set_provider(configured[1])
  }

  # Detect RStudio theme (light / dark) so we can set data-theme on root
  is_dark <- sparx_is_dark_theme()

  # Prism assets from inst/www (bundled, offline-safe)
  prism_resources <- shiny::addResourcePath(
    "sparx_www",
    system.file("www", package = "sparx")
  )

  ui <- miniUI::miniPage(
    shiny::tags$head(
      shiny::tags$style(chat_css()),
      shiny::tags$link(rel = "stylesheet", href = "sparx_www/prism.css"),
      shiny::tags$script(src = "sparx_www/prism.js"),
      shiny::tags$script(src = "sparx_www/prism-r.js"),
      shiny::tags$script(src = "sparx_www/prism-python.js"),
      shiny::tags$script(src = "sparx_www/prism-sql.js"),
      shiny::tags$script(src = "sparx_www/prism-markdown.js"),
      shiny::tags$script(shiny::HTML(sprintf(
        "document.documentElement.setAttribute('data-theme', '%s');",
        if (is_dark) "dark" else "light"
      )))
    ),

    miniUI::gadgetTitleBar(
      "sparx",
      right = miniUI::miniTitleBarButton("close", "Close", primary = FALSE),
      left = miniUI::miniTitleBarButton("clear", "Clear", primary = FALSE)
    ),

    # ── Compact controls bar ───────────────────────────
    shiny::div(
      class = "sparx-controls",
      model_pill_ui("model_pill"),
      provider_select_ui("provider_select"),
      shiny::tags$span(class = "sparx-separator", "|"),
      shiny::actionButton("toggle_live", toggle_label("Live", FALSE),
                          class = "sparx-toggle"),
      shiny::actionButton("toggle_install", toggle_label("Install", FALSE),
                          class = "sparx-toggle"),
      shiny::actionButton("toggle_git", toggle_label("Git", FALSE),
                          class = "sparx-toggle"),
      shiny::span(class = "sparx-usage", shiny::textOutput("token_display", inline = TRUE))
    ),

    miniUI::miniContentPanel(
      shiny::div(
        class = "sparx-container",
        shiny::div(
          id = "sparx-thread",
          class = "sparx-thread",
          shiny::uiOutput("thread")
        ),
        shiny::div(
          class = "sparx-input-area",
          shiny::div(
            class = "sparx-input-wrapper",
            shiny::div(id = "sparx-slash-menu", class = "sparx-slash-menu"),
            shiny::textAreaInput(
              "user_input",
              label = NULL,
              placeholder = rotating_placeholder(),
              rows = 1,
              width = "100%"
            ),
            shiny::div(
              class = "sparx-send-group",
              shiny::actionButton("send", "Send", class = "btn-primary btn-sm"),
              shiny::actionButton("stop", "Stop", class = "btn-danger btn-sm sparx-stop")
            )
          ),
          shiny::div(
            class = "sparx-input-actions",
            shiny::span(class = "sparx-hint",
                        "Cmd/Ctrl+Enter to send \u00b7 / for commands \u00b7 \u2191 to recall")
          )
        )
      )
    ),

    shiny::tags$script(shiny::HTML(cmd_enter_js()))
  )

  server <- function(input, output, session) {
    # ── Provider selection ─────────────────────────────

    shiny::observeEvent(input$provider_select, {
      chosen <- input$provider_select
      if (is.null(chosen) || chosen == get_provider()) return()

      key <- tryCatch(get_api_key(chosen), error = function(e) NULL)
      if (is.null(key) || !nzchar(key)) {
        shiny::showNotification(
          paste0("No API key for ", PROVIDERS[[chosen]]$name,
                 ". Run: sparx::set_api_key(provider = \"", chosen, "\")"),
          type = "warning", duration = 8, session = session
        )
        shiny::updateSelectInput(session, "provider_select",
                                 selected = get_provider())
        return()
      }
      set_provider(chosen)
      shiny::showNotification(
        paste0("Switched to ", PROVIDERS[[chosen]]$name, " (", get_model(), ")"),
        type = "message", duration = 4, session = session
      )
    }, ignoreInit = TRUE)

    # ── Mode toggles ───────────────────────────────────

    live_on    <- shiny::reactiveVal(isTRUE(getOption("sparx.live_execution", FALSE)))
    install_on <- shiny::reactiveVal(isTRUE(getOption("sparx.auto_install", FALSE)))
    git_on     <- shiny::reactiveVal(isTRUE(getOption("sparx.allow_git", FALSE)))

    shiny::observe({ options(sparx.live_execution = live_on()) })
    shiny::observe({ options(sparx.auto_install = install_on()) })
    shiny::observe({ options(sparx.allow_git = git_on()) })

    shiny::observeEvent(input$toggle_live, {
      new_val <- !live_on()
      if (new_val) {
        showToggleWarning("Live execution", session,
          "sparx can now run code in your session. Destructive patterns stay blocked.")
      }
      live_on(new_val)
      shiny::updateActionButton(session, "toggle_live",
                                label = toggle_label("Live", new_val))
    })
    shiny::observeEvent(input$toggle_install, {
      new_val <- !install_on()
      install_on(new_val)
      shiny::updateActionButton(session, "toggle_install",
                                label = toggle_label("Install", new_val))
    })
    shiny::observeEvent(input$toggle_git, {
      new_val <- !git_on()
      git_on(new_val)
      shiny::updateActionButton(session, "toggle_git",
                                label = toggle_label("Git", new_val))
    })

    # ── Stop button ────────────────────────────────────

    shiny::observeEvent(input$stop, {
      sparx_request_abort()
    })

    # ── Token display ──────────────────────────────────

    token_signal <- shiny::reactiveTimer(1500, session)
    output$token_display <- shiny::renderText({
      token_signal()
      i <- .sparx_runtime_state$input_tokens
      o <- .sparx_runtime_state$output_tokens
      if (i + o == 0) return("")
      paste0(format(i, big.mark = ","), " in / ",
             format(o, big.mark = ","), " out")
    })

    # ── Conversation state + restore ───────────────────

    saved <- tryCatch(load_conversation(), error = function(e) NULL)
    initial_messages <- if (!is.null(saved)) saved$messages else list()
    initial_todos <- if (!is.null(saved)) saved$todos else list()
    .sparx_todo_state$items <- initial_todos

    messages <- shiny::reactiveVal(initial_messages)
    thread_ui <- shiny::reactiveVal(
      rebuild_thread_ui_from_messages(initial_messages)
    )
    is_streaming <- shiny::reactiveVal(FALSE)
    current_assistant <- shiny::reactiveVal("")
    active_tool <- shiny::reactiveVal(NULL)

    # Pre-populate input from selection action if present
    shiny::observe({
      pending <- .sparx_state$pending_prompt
      if (!is.null(pending) && nchar(pending) > 0) {
        shiny::updateTextAreaInput(session, "user_input", value = pending)
        .sparx_state$pending_prompt <- NULL
      }
    })

    # ── Thread rendering ───────────────────────────────

    output$thread <- shiny::renderUI({
      rendered <- thread_ui()
      streaming_text <- current_assistant()
      tool <- active_tool()
      todos <- .sparx_todo_state$items

      items <- rendered
      if (nchar(streaming_text) > 0) {
        items <- c(items,
                   list(render_assistant_bubble(streaming_text, streaming = TRUE)))
      }
      if (!is.null(tool)) {
        items <- c(items,
                   list(render_tool_badge(tool$name, tool$input_preview, running = TRUE)))
      }

      if (length(items) == 0 && length(todos) == 0) {
        shiny::div(class = "sparx-welcome", welcome_message_html())
      } else {
        header <- render_todo_list(todos)
        if (!is.null(header)) {
          shiny::tagList(header, items)
        } else {
          shiny::tagList(items)
        }
      }
    })

    # Re-run Prism after every UI update so new code blocks get highlighted
    shiny::observe({
      thread_ui()
      current_assistant()
      session$sendCustomMessage("sparx_highlight", list())
    })

    # ── Send handler — kicks off agentic loop ──────────

    shiny::observeEvent(input$send, {
      if (is_streaming()) return()
      user_text <- trimws(input$user_input %||% "")
      if (nchar(user_text) == 0) return()

      shiny::updateTextAreaInput(session, "user_input", value = "")

      # Handle slash commands BEFORE sending to the agent
      slash_handled <- handle_slash_command(user_text, session,
                                            messages, thread_ui,
                                            current_assistant, active_tool)
      if (slash_handled) return()

      new_messages <- c(messages(), list(list(role = "user", content = user_text)))
      thread_ui(c(thread_ui(), list(render_user_bubble(user_text))))

      is_streaming(TRUE)
      session$sendCustomMessage("sparx_set_streaming", TRUE)
      current_assistant("")
      active_tool(NULL)

      result <- tryCatch(
        run_agentic_turn(
          messages = new_messages,
          on_text_chunk = function(chunk) {
            current_assistant(paste0(current_assistant(), chunk))
          },
          on_tool_start = function(name, id) {
            txt <- current_assistant()
            if (nchar(txt) > 0) {
              thread_ui(c(thread_ui(),
                          list(render_assistant_bubble(txt, streaming = FALSE))))
              current_assistant("")
            }
            # Look up the tool's input from the latest messages for preview text
            last_asst <- tail(new_messages, 1)[[1]]
            input_preview <- tryCatch({
              # Not available yet at start — it's in the incoming stream
              ""
            }, error = function(e) "")
            active_tool(list(name = name, id = id, input_preview = input_preview))
          },
          on_tool_result = function(name, id, result_text) {
            # Find the tool input from the current messages so we can preview it
            tool_input <- find_tool_input(messages_state_snapshot(new_messages, thread_ui()), id)
            thread_ui(c(thread_ui(),
                        list(render_tool_result(name, result_text, input = tool_input))))
            active_tool(NULL)
          },
          on_iteration = function(iter) {
            if (iter > 1) current_assistant("")
          }
        ),
        error = function(e) {
          list(messages = new_messages,
               final_text = paste0("**Error:** ", conditionMessage(e)),
               iterations = 0)
        }
      )

      final_txt <- current_assistant()
      if (nchar(final_txt) > 0) {
        thread_ui(c(thread_ui(),
                    list(render_assistant_bubble(final_txt, streaming = FALSE))))
        current_assistant("")
      }

      messages(result$messages)
      active_tool(NULL)
      is_streaming(FALSE)
      session$sendCustomMessage("sparx_set_streaming", FALSE)

      tryCatch(save_conversation(result$messages, .sparx_todo_state$items),
               error = function(e) NULL)
    })

    # Code action handlers (Insert / Run from code blocks)
    shiny::observeEvent(input$insert_code, {
      code <- input$insert_code
      if (!is.null(code) && nchar(code) > 0) insert_code_at_cursor(code)
    })
    shiny::observeEvent(input$run_code, {
      code <- input$run_code
      if (!is.null(code) && nchar(code) > 0) run_code_in_console(code)
    })

    # Clear / close
    shiny::observeEvent(input$clear, {
      messages(list())
      thread_ui(list())
      current_assistant("")
      active_tool(NULL)
      .sparx_todo_state$items <- list()
      sparx_reset_tokens()
      tryCatch(clear_saved_conversation(), error = function(e) NULL)
    })
    shiny::observeEvent(input$close,  shiny::stopApp())
    shiny::observeEvent(input$done,   shiny::stopApp())
    shiny::observeEvent(input$cancel, shiny::stopApp())
  }

  viewer <- shiny::paneViewer(minHeight = 500)
  shiny::runGadget(ui, server, viewer = viewer)
}

# ── Slash commands ─────────────────────────────────────────────────────────

#' Handle special slash commands before sending to the agent
#' @keywords internal
handle_slash_command <- function(text, session, messages, thread_ui,
                                  current_assistant, active_tool) {
  if (!startsWith(text, "/")) return(FALSE)
  parts <- strsplit(text, "\\s+", perl = TRUE)[[1]]
  cmd <- parts[1]
  args <- parts[-1]

  switch(cmd,
    "/clear" = {
      messages(list()); thread_ui(list()); current_assistant("")
      active_tool(NULL); .sparx_todo_state$items <- list()
      sparx_reset_tokens()
      tryCatch(clear_saved_conversation(), error = function(e) NULL)
      shiny::showNotification("Conversation cleared.", type = "message",
                              duration = 2, session = session)
      TRUE
    },
    "/model" = {
      if (length(args) == 0) {
        shiny::showNotification(paste0("Current model: ", get_model()),
                                type = "message", duration = 3, session = session)
      } else {
        m <- args[1]
        # Friendly aliases
        aliases <- list(
          haiku  = "claude-haiku-4-5-20251001",
          sonnet = "claude-sonnet-4-5-20250929",
          opus   = "claude-opus-4-5-20251001",
          `4o`   = "gpt-4o",
          mini   = "gpt-4o-mini"
        )
        if (!is.null(aliases[[m]])) m <- aliases[[m]]
        options(sparx.model = m)
        shiny::showNotification(paste0("Model set to ", m),
                                type = "message", duration = 3, session = session)
      }
      TRUE
    },
    "/provider" = {
      if (length(args) == 0) {
        shiny::showNotification(paste0("Current provider: ", get_provider()),
                                type = "message", duration = 3, session = session)
      } else {
        p <- args[1]
        tryCatch({
          set_provider(p)
          shiny::updateSelectInput(session, "provider_select", selected = p)
          shiny::showNotification(paste0("Provider: ", p), type = "message",
                                  duration = 3, session = session)
        }, error = function(e) {
          shiny::showNotification(conditionMessage(e), type = "error",
                                  duration = 5, session = session)
        })
      }
      TRUE
    },
    "/retry" = {
      msgs <- messages()
      # Find last user turn
      last_user <- NULL
      for (i in rev(seq_along(msgs))) {
        if (identical(msgs[[i]]$role, "user") && is.character(msgs[[i]]$content)) {
          last_user <- msgs[[i]]$content
          break
        }
      }
      if (is.null(last_user)) {
        shiny::showNotification("No previous message to retry.", type = "warning",
                                duration = 3, session = session)
      } else {
        shiny::updateTextAreaInput(session, "user_input", value = last_user)
      }
      TRUE
    },
    "/help" = {
      help_text <- paste(
        "Slash commands:",
        "  /clear            clear the conversation",
        "  /model haiku      switch model (haiku/sonnet/opus/4o/mini)",
        "  /provider openai  switch provider",
        "  /retry            recall the last user message",
        "  /help             this help",
        sep = "\n"
      )
      thread_ui(c(thread_ui(),
                  list(render_assistant_bubble(help_text, streaming = FALSE))))
      TRUE
    },
    FALSE
  )
}

# ── Shared helpers ─────────────────────────────────────────────────────────

#' @keywords internal
model_pill_ui <- function(input_id) {
  shiny::div(
    class = "sparx-model-pill",
    shiny::HTML('<span class="sparx-model-dot"></span>'),
    shiny::span(short_model_name(get_model()))
  )
}

#' @keywords internal
short_model_name <- function(model) {
  # claude-sonnet-4-5-20250929 -> Sonnet
  if (grepl("haiku", model, ignore.case = TRUE)) return("Claude Haiku")
  if (grepl("sonnet", model, ignore.case = TRUE)) return("Claude Sonnet")
  if (grepl("opus", model, ignore.case = TRUE)) return("Claude Opus")
  if (grepl("gpt-4o-mini", model, ignore.case = TRUE)) return("GPT-4o mini")
  if (grepl("gpt-4o", model, ignore.case = TRUE)) return("GPT-4o")
  if (grepl("gpt", model, ignore.case = TRUE)) return(model)
  model
}

#' Rotating placeholder text for input area
#' @keywords internal
rotating_placeholder <- function() {
  hints <- c(
    "Ask sparx \u2014 e.g., fit a mixed model on df",
    "Ask sparx \u2014 e.g., why is my code erroring?",
    "Ask sparx \u2014 e.g., which test for paired data?",
    "Ask sparx \u2014 e.g., clean the missing values in df"
  )
  sample(hints, 1)
}

#' @keywords internal
toggle_label <- function(name, on) {
  paste0(name, ": ", if (isTRUE(on)) "ON" else "off")
}

#' @keywords internal
showToggleWarning <- function(feature, session, detail) {
  shiny::showNotification(
    paste0(feature, " enabled. ", detail),
    type = "warning", duration = 6, session = session
  )
}

#' Provider dropdown UI (kept for now, will be replaced by model-pill in v1)
#' @keywords internal
provider_select_ui <- function(input_id) {
  all_names <- names(PROVIDERS)
  current <- get_provider()
  configured <- configured_providers()

  choices <- setNames(all_names, vapply(all_names, function(p) {
    label <- PROVIDERS[[p]]$name
    if (!(p %in% configured)) label <- paste0(label, " (no key)")
    label
  }, character(1)))

  shiny::selectInput(
    inputId = input_id, label = NULL,
    choices = choices, selected = current, width = "160px"
  )
}

#' Find a tool_use block's input by id, searching in-progress messages
#' @keywords internal
find_tool_input <- function(messages, tool_id) {
  for (msg in rev(messages)) {
    if (identical(msg$role, "assistant") && is.list(msg$content)) {
      for (block in msg$content) {
        if (identical(block$type, "tool_use") && identical(block$id, tool_id)) {
          return(block$input)
        }
      }
    }
  }
  NULL
}

#' Build a messages snapshot that includes the assistant's in-progress turn
#' @keywords internal
messages_state_snapshot <- function(messages, thread_ui) {
  messages
}

#' Rebuild the thread UI from saved messages
#' @keywords internal
rebuild_thread_ui_from_messages <- function(messages) {
  if (length(messages) == 0) return(list())
  items <- list()
  for (msg in messages) {
    role <- msg$role
    content <- msg$content

    if (role == "user") {
      if (is.character(content) && length(content) == 1) {
        items[[length(items) + 1]] <- render_user_bubble(content)
      }
    } else if (role == "assistant") {
      if (is.list(content)) {
        for (block in content) {
          type <- block$type %||% "text"
          if (type == "text" && !is.null(block$text)) {
            items[[length(items) + 1]] <- render_assistant_bubble(block$text, streaming = FALSE)
          } else if (type == "tool_use") {
            items[[length(items) + 1]] <- render_tool_badge(
              block$name %||% "tool",
              extract_input_preview(block$name %||% "", block$input),
              running = FALSE
            )
          }
        }
      } else if (is.character(content)) {
        items[[length(items) + 1]] <- render_assistant_bubble(content, streaming = FALSE)
      }
    }
  }
  items
}

# ── Editor integration helpers ─────────────────────────────────────────────

#' @keywords internal
insert_code_at_cursor <- function(code) {
  tryCatch(
    rstudioapi::insertText(text = paste0(code, "\n")),
    error = function(e) message("Could not insert code: ", conditionMessage(e))
  )
}

#' @keywords internal
run_code_in_console <- function(code) {
  tryCatch(
    rstudioapi::sendToConsole(code, execute = TRUE),
    error = function(e) message("Could not run code: ", conditionMessage(e))
  )
}
