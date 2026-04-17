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

  if (is.null(get_api_key()) || nchar(get_api_key()) == 0) {
    if (interactive()) {
      message("sparx: no API key found. Let's set one up.")
      set_api_key()
    } else {
      stop("Run sparx::set_api_key() first.")
    }
  }

  ui <- miniUI::miniPage(
    shiny::tags$head(shiny::tags$style(chat_css())),
    miniUI::gadgetTitleBar(
      "sparx",
      right = miniUI::miniTitleBarButton("close", "Close", primary = FALSE),
      left = miniUI::miniTitleBarButton("clear", "Clear", primary = FALSE)
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
            shiny::actionButton("send", "Send", class = "btn-primary btn-sm"),
            shiny::span(id = "sparx-hint", class = "sparx-hint", "Cmd/Ctrl+Enter")
          )
        )
      )
    ),
    shiny::tags$script(shiny::HTML(cmd_enter_js()))
  )

  server <- function(input, output, session) {
    # ── Reactive state ────────────────────────────────────

    messages <- shiny::reactiveVal(list())  # Anthropic-format conversation history
    thread_ui <- shiny::reactiveVal(list())  # rendered UI items (user, assistant, tool)
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

      items <- rendered
      if (nchar(streaming_text) > 0) {
        items <- c(items, list(render_assistant_bubble(streaming_text, streaming = TRUE)))
      }
      if (!is.null(tool)) {
        items <- c(items, list(render_tool_badge(tool$name, running = TRUE)))
      }

      if (length(items) == 0) {
        shiny::div(class = "sparx-welcome", welcome_message_html())
      } else {
        shiny::tagList(items)
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
    })

    shiny::observeEvent(input$close, shiny::stopApp())
    shiny::observeEvent(input$done, shiny::stopApp())
    shiny::observeEvent(input$cancel, shiny::stopApp())
  }

  viewer <- shiny::paneViewer(minHeight = 400)
  shiny::runGadget(ui, server, viewer = viewer)
}

# ── Editor integration helpers ─────────────────────────────

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
