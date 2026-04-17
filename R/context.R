#' Context gathering — reads the user's current RStudio state
#'
#' Before sending a request to Claude, we collect:
#' - Current editor document (content + cursor position + selection)
#' - Active dataframes in the R session (names + shapes + column types)
#' - Installed packages
#' - Recent console history
#'
#' This context is injected into the system prompt so the agent can reason
#' about the user's actual environment.

#' Gather full context from the current RStudio session
#'
#' @return A named list with fields: script, cursor, selection,
#'   dataframes, packages, history
#'
#' @keywords internal
gather_context <- function() {
  list(
    script = safe_get_active_document(),
    cursor = safe_get_cursor_position(),
    selection = safe_get_selection(),
    dataframes = list_dataframes(),
    packages = loaded_packages(),
    r_version = as.character(getRversion())
  )
}

#' Get the active editor document's content and path
#' @keywords internal
safe_get_active_document <- function() {
  tryCatch({
    ctx <- rstudioapi::getSourceEditorContext()
    list(
      path = ctx$path %||% "<unsaved>",
      contents = paste(ctx$contents, collapse = "\n")
    )
  }, error = function(e) {
    list(path = NA_character_, contents = "")
  })
}

#' Get cursor line number
#' @keywords internal
safe_get_cursor_position <- function() {
  tryCatch({
    ctx <- rstudioapi::getSourceEditorContext()
    if (length(ctx$selection) > 0) {
      start <- ctx$selection[[1]]$range$start
      list(line = start[["row"]], column = start[["column"]])
    } else {
      list(line = NA_integer_, column = NA_integer_)
    }
  }, error = function(e) {
    list(line = NA_integer_, column = NA_integer_)
  })
}

#' Get current text selection (if any)
#' @keywords internal
safe_get_selection <- function() {
  tryCatch({
    ctx <- rstudioapi::getSourceEditorContext()
    if (length(ctx$selection) > 0) {
      ctx$selection[[1]]$text
    } else {
      ""
    }
  }, error = function(e) "")
}

#' Summarize all dataframes in .GlobalEnv
#'
#' Returns structured info the agent can reason about without seeing
#' the full data.
#'
#' @keywords internal
list_dataframes <- function() {
  obj_names <- ls(envir = .GlobalEnv)
  dfs <- list()

  for (name in obj_names) {
    obj <- tryCatch(get(name, envir = .GlobalEnv), error = function(e) NULL)
    if (is.data.frame(obj)) {
      dfs[[name]] <- list(
        rows = nrow(obj),
        cols = ncol(obj),
        columns = lapply(names(obj), function(col) {
          list(
            name = col,
            type = paste(class(obj[[col]]), collapse = ","),
            n_unique = tryCatch(length(unique(obj[[col]])), error = function(e) NA),
            n_missing = sum(is.na(obj[[col]]))
          )
        })
      )
    }
  }

  dfs
}

#' List currently loaded (attached) packages
#' @keywords internal
loaded_packages <- function() {
  setdiff(
    .packages(),
    c("base", "utils", "graphics", "grDevices", "stats", "datasets", "methods")
  )
}

#' Null-coalescing operator
#' @keywords internal
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
