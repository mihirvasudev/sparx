#' Open the sparx chat gadget
#'
#' Primary entry point for the addin. Opens a miniUI gadget in RStudio's
#' viewer pane where the user can ask questions and get streaming AI responses.
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
            placeholder = "Ask sparx (Cmd+Enter to send)",
            rows = 3,
            width = "100%",
            resize = "vertical"
          ),
          shiny::div(
            class = "sparx-input-actions",
            shiny::actionButton("send", "Send", class = "btn-primary btn-sm"),
            shiny::span(
              id = "sparx-hint",
              class = "sparx-hint",
              "Cmd/Ctrl+Enter"
            )
          )
        )
      )
    ),
    # JS: Cmd+Enter to send
    shiny::tags$script(shiny::HTML(cmd_enter_js()))
  )

  server <- function(input, output, session) {
    # Conversation state
    messages <- shiny::reactiveVal(list())
    thread_ui <- shiny::reactiveVal(list())
    is_streaming <- shiny::reactiveVal(FALSE)
    current_assistant <- shiny::reactiveVal("")

    # If a pending prompt was set by a selection action, populate the input
    shiny::observe({
      pending <- .sparx_state$pending_prompt
      if (!is.null(pending) && nchar(pending) > 0) {
        shiny::updateTextAreaInput(session, "user_input", value = pending)
        .sparx_state$pending_prompt <- NULL
      }
    })

    # Render the full thread
    output$thread <- shiny::renderUI({
      rendered <- thread_ui()
      streaming_text <- current_assistant()

      all_items <- rendered
      if (nchar(streaming_text) > 0) {
        all_items <- c(
          all_items,
          list(render_assistant_bubble(streaming_text, streaming = TRUE))
        )
      }

      if (length(all_items) == 0) {
        shiny::div(class = "sparx-welcome", welcome_message_html())
      } else {
        shiny::tagList(all_items)
      }
    })

    # Handle send
    shiny::observeEvent(input$send, {
      if (is_streaming()) return()
      user_text <- trimws(input$user_input %||% "")
      if (nchar(user_text) == 0) return()

      # Clear input
      shiny::updateTextAreaInput(session, "user_input", value = "")

      # Append user bubble
      new_messages <- c(messages(), list(list(role = "user", content = user_text)))
      messages(new_messages)
      thread_ui(c(thread_ui(), list(render_user_bubble(user_text))))

      # Kick off streaming request
      is_streaming(TRUE)
      current_assistant("")

      # Gather context fresh on each request
      context <- gather_context()
      system_prompt <- build_system_prompt(context)

      # Run synchronously (Shiny gadgets are single-threaded, so we stream
      # inline; each chunk updates the reactive value)
      result <- tryCatch(
        call_claude_streaming(
          system_prompt = system_prompt,
          messages = format_for_anthropic(new_messages),
          on_chunk = function(chunk) {
            current_assistant(paste0(current_assistant(), chunk))
          }
        ),
        error = function(e) {
          list(text = paste0("**Error:** ", conditionMessage(e)))
        }
      )

      # Persist the final assistant message
      final_text <- result$text
      thread_ui(c(
        thread_ui(),
        list(render_assistant_bubble(final_text, streaming = FALSE))
      ))
      messages(c(new_messages, list(list(role = "assistant", content = final_text))))

      current_assistant("")
      is_streaming(FALSE)
    })

    # Insert / Run button handlers come via custom input from JS
    shiny::observeEvent(input$insert_code, {
      code <- input$insert_code
      if (!is.null(code) && nchar(code) > 0) {
        insert_code_at_cursor(code)
      }
    })

    shiny::observeEvent(input$run_code, {
      code <- input$run_code
      if (!is.null(code) && nchar(code) > 0) {
        run_code_in_console(code)
      }
    })

    # Clear conversation
    shiny::observeEvent(input$clear, {
      messages(list())
      thread_ui(list())
      current_assistant("")
    })

    # Close gadget
    shiny::observeEvent(input$close, {
      shiny::stopApp()
    })
    shiny::observeEvent(input$done, {
      shiny::stopApp()
    })
    shiny::observeEvent(input$cancel, {
      shiny::stopApp()
    })
  }

  viewer <- shiny::paneViewer(minHeight = 400)
  shiny::runGadget(ui, server, viewer = viewer)
}

#' Format message list for Anthropic API
#' @keywords internal
format_for_anthropic <- function(messages) {
  lapply(messages, function(m) {
    list(role = m$role, content = m$content)
  })
}

#' Insert code at current cursor position
#' @keywords internal
insert_code_at_cursor <- function(code) {
  tryCatch({
    rstudioapi::insertText(text = paste0(code, "\n"))
  }, error = function(e) {
    message("Could not insert code: ", conditionMessage(e))
  })
}

#' Run code in the live R console
#' @keywords internal
run_code_in_console <- function(code) {
  tryCatch({
    rstudioapi::sendToConsole(code, execute = TRUE)
  }, error = function(e) {
    message("Could not run code: ", conditionMessage(e))
  })
}
