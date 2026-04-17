#' Persistent conversations
#'
#' Each project's chat history is saved to:
#'   <project_root>/.sparx/conversation.json
#'
#' This is project-local (so you can have different chats per project),
#' stored under a dotfile directory that git-ignores well. On `open_chat()`,
#' if a conversation file exists for the current project, it's loaded.
#'
#' Serialization format:
#' {
#'   "version": 1,
#'   "created_at": "...",
#'   "updated_at": "...",
#'   "messages": [...],
#'   "todos": [...]
#' }

SPARX_PERSIST_VERSION <- 1L
SPARX_PERSIST_DIR <- ".sparx"
SPARX_PERSIST_FILE <- "conversation.json"

#' Get the path to the conversation file for the current project
#' @keywords internal
conversation_file_path <- function(root = NULL) {
  if (is.null(root)) root <- find_project_root()
  dir_path <- file.path(root, SPARX_PERSIST_DIR)
  file.path(dir_path, SPARX_PERSIST_FILE)
}

#' Save the current conversation to the project's .sparx directory
#'
#' @param messages List of Anthropic-format message objects
#' @param todos Current todo list (from .sparx_todo_state$items)
#'
#' @return Invisible TRUE on success, FALSE on failure
#' @keywords internal
save_conversation <- function(messages, todos = list()) {
  if (is.null(messages) || length(messages) == 0) {
    return(invisible(FALSE))
  }

  root <- tryCatch(find_project_root(), error = function(e) NULL)
  if (is.null(root)) return(invisible(FALSE))

  dir_path <- file.path(root, SPARX_PERSIST_DIR)
  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
    # Write a .gitignore inside .sparx so conversations don't leak to repos
    writeLines(c("# sparx local state", "*"),
               file.path(dir_path, ".gitignore"))
  }

  payload <- list(
    version = SPARX_PERSIST_VERSION,
    created_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    updated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    messages = messages,
    todos = todos
  )

  path <- conversation_file_path(root)

  # If file exists, preserve created_at
  if (file.exists(path)) {
    existing <- tryCatch(
      jsonlite::fromJSON(path, simplifyVector = FALSE),
      error = function(e) NULL
    )
    if (!is.null(existing$created_at)) {
      payload$created_at <- existing$created_at
    }
  }

  tryCatch({
    json <- jsonlite::toJSON(payload, auto_unbox = TRUE, pretty = TRUE, null = "null")
    writeLines(json, path, useBytes = TRUE)
    invisible(TRUE)
  }, error = function(e) {
    warning("sparx: failed to save conversation: ", conditionMessage(e))
    invisible(FALSE)
  })
}

#' Load a previously-saved conversation for the current project
#'
#' @return List with fields `messages` and `todos`, or NULL if no saved
#'   conversation exists.
#' @keywords internal
load_conversation <- function(root = NULL) {
  path <- conversation_file_path(root)
  if (!file.exists(path)) return(NULL)

  tryCatch({
    payload <- jsonlite::fromJSON(path, simplifyVector = FALSE)
    list(
      messages = payload$messages %||% list(),
      todos = payload$todos %||% list(),
      updated_at = payload$updated_at %||% NA_character_
    )
  }, error = function(e) {
    warning("sparx: failed to load conversation: ", conditionMessage(e))
    NULL
  })
}

#' Clear the saved conversation for the current project
#' @keywords internal
clear_saved_conversation <- function() {
  path <- conversation_file_path()
  if (file.exists(path)) {
    file.remove(path)
    invisible(TRUE)
  } else {
    invisible(FALSE)
  }
}
