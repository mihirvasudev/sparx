#' Open the sparx chat gadget
#'
#' Primary entry point for the addin. Opens a miniUI gadget in RStudio's
#' viewer pane where the user can ask questions and get streaming AI
#' responses with tool-use visibility.
#'
#' @export
open_chat <- function() {
  if (!requireNamespace("shiny", quietly = TRUE) ||
      !requireNamespace("miniUI", quietly = TRUE)) {
    stop("sparx requires `shiny` and `miniUI`. Install them with install.packages(c('shiny', 'miniUI')).")
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
    # Switch to the first configured provider
    set_provider(configured[1])
  }

  ui <- miniUI::miniPage(
    shiny::tags$head(shiny::tags$style(chat_css())),
    miniUI::gadgetTitleBar(
      "sparx",
      right = miniUI::miniTitleBarButton("close", "Close", primary = FALSE),
      left = miniUI::miniTitleBarButton("clear", "Clear", primary = FALSE)
    ),
    # Provider + toggle bar
    shiny::div(
      class = "sparx-controls",
      shiny::tags$span(class = "sparx-mode-label", "Provider:"),
      provider_select_ui("provider_select"),
      shiny::tags$span(class = "sparx-separator", "|"),
      shiny::actionButton("toggle_live", toggle_label("Live exec", FALSE),
                          class = "sparx-toggle"),
      shiny::actionButton("toggle_install", toggle_label("Auto-install", FALSE),
                          class = "sparx-toggle"),
      shiny::actionButton("toggle_git", toggle_label("Git writes", FALSE),
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
          shiny::textAreaInput(
            "user_input",
            label = NULL,
            placeholder = "Ask sparx (Cmd/Ctrl+Enter to send)",
            rows = 3,
            width = "100%",
            resize = "vertical"
          ),
          shiny::div(
            class = "sparx-input-actions",
            shiny::div(
              class = "sparx-send-group",
              shiny::actionButton("send", "Send", class = "btn-primary btn-sm"),
              shiny::actionButton("stop", "Stop", class = "btn-danger btn-sm sparx-stop")
            ),
            shiny::span(id = "sparx-hint", class = "sparx-hint", "Cmd/Ctrl+Enter to send")
          )
        )
      )
    ),
    shiny::tags$script(shiny::HTML(cmd_enter_js()))
  )

  server <- function(input, output, session) {
    # ── Reactive state ────────────────────────────────────

    # ── Provider selection ─────────────────────────────────

    shiny::observeEvent(input$provider_select, {
      chosen <- input$provider_select
      if (is.null(chosen) || chosen == get_provider()) return()

      # If the chosen provider isn't configured, prompt for a key
      key <- tryCatch(get_api_key(chosen), error = function(e) NULL)
      if (is.null(key) || !nzchar(key)) {
        shiny::showNotification(
          paste0("No API key for ", PROVIDERS[[chosen]]$name,
                 ". Set one with sparx::set_api_key(provider = \"", chosen, "\")"),
          type = "warning",
          duration = 8,
          session = session
        )
        # Revert the dropdown
        shiny::updateSelectInput(session, "provider_select", selected = get_provider())
        return()
      }

      set_provider(chosen)
      shiny::showNotification(
        paste0("Now using ", PROVIDERS[[chosen]]$name,
               " (model: ", get_model(), ")"),
        type = "message",
        duration = 4,
        session = session
      )
    }, ignoreInit = TRUE)

    # ── Mode toggle state ──────────────────────────────────

    live_on <- shiny::reactiveVal(isTRUE(getOption("sparx.live_execution", FALSE)))
    install_on <- shiny::reactiveVal(isTRUE(getOption("sparx.auto_install", FALSE)))
    git_on <- shiny::reactiveVal(isTRUE(getOption("sparx.allow_git", FALSE)))

    # Sync toggles to options() so the tools pick them up
    shiny::observe({ options(sparx.live_execution = live_on()) })
    shiny::observe({ options(sparx.auto_install = install_on()) })
    shiny::observe({ options(sparx.allow_git = git_on()) })

    # Toggle buttons
    shiny::observeEvent(input$toggle_live, {
      new_val <- !live_on()
      if (new_val) {
        showToggleWarning("Live execution", session,
          "Claude will now run code directly in your R session (state persists). Destructive patterns are still blocked.")
      }
      live_on(new_val)
      shiny::updateActionButton(session, "toggle_live", label = toggle_label("Live exec", new_val))
    })
    shiny::observeEvent(input$toggle_install, {
      new_val <- !install_on()
      install_on(new_val)
      shiny::updateActionButton(session, "toggle_install", label = toggle_label("Auto-install", new_val))
    })
    shiny::observeEvent(input$toggle_git, {
      new_val <- !git_on()
      git_on(new_val)
      shiny::updateActionButton(session, "toggle_git", label = toggle_label("Git writes", new_val))
    })

    # Stop button
    shiny::observeEvent(input$stop, {
      sparx_request_abort()
    })

    # Token display (reactive: polls state every second)
    token_signal <- shiny::reactiveTimer(1000, session)
    output$token_display <- shiny::renderText({
      token_signal()
      i <- .sparx_runtime_state$input_tokens
      o <- .sparx_runtime_state$output_tokens
      if (i + o == 0) return("")
      paste0("Tokens: ", format(i, big.mark = ","), " in, ",
             format(o, big.mark = ","), " out")
    })

    # Try to restore saved conversation for this project
    saved <- tryCatch(load_conversation(), error = function(e) NULL)

    initial_messages <- if (!is.null(saved)) saved$messages else list()
    initial_todos <- if (!is.null(saved)) saved$todos else list()
    .sparx_todo_state$items <- initial_todos

    messages <- shiny::reactiveVal(initial_messages)  # Anthropic-format conversation history
    thread_ui <- shiny::reactiveVal(
      rebuild_thread_ui_from_messages(initial_messages)
    )  # rendered UI items
    is_streaming <- shiny::reactiveVal(FALSE)
    current_assistant <- shiny::reactiveVal("")  # streaming text buffer
    active_tool <- shiny::reactiveVal(NULL)  # {name, id} of currently-running tool

    # Handle selection-action pre-fill (from Explain/Fix/Improve)
    shiny::observe({
      pending <- .sparx_state$pending_prompt
      if (!is.null(pending) && nchar(pending) > 0) {
        shiny::updateTextAreaInput(session, "user_input", value = pending)
        .sparx_state$pending_prompt <- NULL
      }
    })

    # ── Thread rendering ──────────────────────────────────

    output$thread <- shiny::renderUI({
      rendered <- thread_ui()
      streaming_text <- current_assistant()
      tool <- active_tool()

      # Read the current todo list from package state
      todos <- .sparx_todo_state$items

      items <- rendered
      if (nchar(streaming_text) > 0) {
        items <- c(items, list(render_assistant_bubble(streaming_text, streaming = TRUE)))
      }
      if (!is.null(tool)) {
        items <- c(items, list(render_tool_badge(tool$name, running = TRUE)))
      }

      if (length(items) == 0 && length(todos) == 0) {
        shiny::div(class = "sparx-welcome", welcome_message_html())
      } else {
        # Todos render ABOVE the thread (as a persistent header)
        header <- render_todo_list(todos)
        if (!is.null(header)) {
          shiny::tagList(header, items)
        } else {
          shiny::tagList(items)
        }
      }
    })

    # ── Send handler (triggers agentic loop) ──────────────

    shiny::observeEvent(input$send, {
      if (is_streaming()) return()
      user_text <- trimws(input$user_input %||% "")
      if (nchar(user_text) == 0) return()

      shiny::updateTextAreaInput(session, "user_input", value = "")

      # Append user bubble immediately
      new_messages <- c(messages(), list(list(role = "user", content = user_text)))
      thread_ui(c(thread_ui(), list(render_user_bubble(user_text))))

      is_streaming(TRUE)
      session$sendCustomMessage("sparx_set_streaming", TRUE)
      current_assistant("")
      active_tool(NULL)

      # Kick off the agentic loop (synchronous within Shiny gadget)
      result <- tryCatch(
        run_agentic_turn(
          messages = new_messages,
          on_text_chunk = function(chunk) {
            current_assistant(paste0(current_assistant(), chunk))
          },
          on_tool_start = function(name, id) {
            # Finalize any in-progress text bubble before showing tool
            txt <- current_assistant()
            if (nchar(txt) > 0) {
              thread_ui(c(thread_ui(), list(render_assistant_bubble(txt, streaming = FALSE))))
              current_assistant("")
            }
            active_tool(list(name = name, id = id))
          },
          on_tool_result = function(name, id, result) {
            # Convert tool badge from "running" → "done" and append result
            thread_ui(c(
              thread_ui(),
              list(render_tool_result(name, result))
            ))
            active_tool(NULL)
          },
          on_iteration = function(iter) {
            # Reset current_assistant between iterations so we don't
            # accumulate across multiple assistant turns
            if (iter > 1) current_assistant("")
          }
        ),
        error = function(e) {
          list(messages = new_messages,
               final_text = paste0("**Error:** ", conditionMessage(e)),
               iterations = 0)
        }
      )

      # Finalize: the last current_assistant chunk belongs to the final text
      final_txt <- current_assistant()
      if (nchar(final_txt) > 0) {
        thread_ui(c(thread_ui(), list(render_assistant_bubble(final_txt, streaming = FALSE))))
        current_assistant("")
      } else if (nchar(result$final_text %||% "") > 0 && length(thread_ui()) > 0) {
        # Edge case: no streamed text but the result has final text
        last_item <- thread_ui()[[length(thread_ui())]]
        # Only append if we didn't already show this
        # (defensive — usually on_text_chunk covers it)
      }

      messages(result$messages)
      active_tool(NULL)
      is_streaming(FALSE)
      session$sendCustomMessage("sparx_set_streaming", FALSE)

      # Persist to disk for next session
      tryCatch(
        save_conversation(result$messages, .sparx_todo_state$items),
        error = function(e) NULL
      )
    })

    # ── Code action handlers (Insert / Run from code blocks) ─

    shiny::observeEvent(input$insert_code, {
      code <- input$insert_code
      if (!is.null(code) && nchar(code) > 0) insert_code_at_cursor(code)
    })

    shiny::observeEvent(input$run_code, {
      code <- input$run_code
      if (!is.null(code) && nchar(code) > 0) run_code_in_console(code)
    })

    # ── Clear / Close ─────────────────────────────────────

    shiny::observeEvent(input$clear, {
      messages(list())
      thread_ui(list())
      current_assistant("")
      active_tool(NULL)
      .sparx_todo_state$items <- list()
      sparx_reset_tokens()
      tryCatch(clear_saved_conversation(), error = function(e) NULL)
    })

    shiny::observeEvent(input$close, shiny::stopApp())
    shiny::observeEvent(input$done, shiny::stopApp())
    shiny::observeEvent(input$cancel, shiny::stopApp())
  }

  viewer <- shiny::paneViewer(minHeight = 400)
  shiny::runGadget(ui, server, viewer = viewer)
}

# ── Editor integration helpers ─────────────────────────────

#' Compose a label for a toggle button showing current state
#' @keywords internal
toggle_label <- function(name, on) {
  paste0(name, ": ", if (isTRUE(on)) "ON" else "off")
}

#' Provider dropdown UI
#'
#' Lists all configured providers; the user can switch mid-session.
#' Unconfigured providers appear greyed with "(set key)" and clicking them
#' opens the key prompt.
#' @keywords internal
provider_select_ui <- function(input_id) {
  configured <- configured_providers()
  all_names <- names(PROVIDERS)
  current <- get_provider()

  choices <- setNames(all_names, vapply(all_names, function(p) {
    label <- PROVIDERS[[p]]$name
    if (!(p %in% configured)) label <- paste0(label, " (no key)")
    label
  }, character(1)))

  shiny::selectInput(
    inputId = input_id,
    label = NULL,
    choices = choices,
    selected = current,
    width = "180px"
  )
}

#' Show a one-time warning when the user enables a powerful toggle
#' @keywords internal
showToggleWarning <- function(feature, session, detail) {
  shiny::showNotification(
    paste0(feature, " enabled. ", detail),
    type = "warning",
    duration = 6,
    session = session
  )
}

#' Rebuild the rendered thread UI from a saved messages array
#'
#' Walks the Anthropic-format messages list and produces the corresponding
#' list of UI items (user bubble, assistant bubble, tool badges).
#' @keywords internal
rebuild_thread_ui_from_messages <- function(messages) {
  if (length(messages) == 0) return(list())

  items <- list()
  for (msg in messages) {
    role <- msg$role
    content <- msg$content

    if (role == "user") {
      # User messages might be a plain string (first turn) or a list of
      # tool_result blocks (continuation turns — don't render these)
      if (is.character(content) && length(content) == 1) {
        items[[length(items) + 1]] <- render_user_bubble(content)
      }
      # Tool results are rendered when the assistant turn's tool_use is seen
    } else if (role == "assistant") {
      # Assistant content is a list of blocks (text and/or tool_use)
      if (is.list(content)) {
        for (block in content) {
          type <- block$type %||% "text"
          if (type == "text" && !is.null(block$text)) {
            items[[length(items) + 1]] <- render_assistant_bubble(block$text, streaming = FALSE)
          } else if (type == "tool_use") {
            # On replay, we don't have the tool_result text handy (they're in
            # the next user message). Just render a minimal completed tool badge.
            items[[length(items) + 1]] <- render_tool_badge(block$name %||% "tool", running = FALSE)
          }
        }
      } else if (is.character(content)) {
        items[[length(items) + 1]] <- render_assistant_bubble(content, streaming = FALSE)
      }
    }
  }
  items
}

#' Insert code at current cursor position
#' @keywords internal
insert_code_at_cursor <- function(code) {
  tryCatch(
    rstudioapi::insertText(text = paste0(code, "\n")),
    error = function(e) message("Could not insert code: ", conditionMessage(e))
  )
}

#' Run code in the live R console
#' @keywords internal
run_code_in_console <- function(code) {
  tryCatch(
    rstudioapi::sendToConsole(code, execute = TRUE),
    error = function(e) message("Could not run code: ", conditionMessage(e))
  )
}
