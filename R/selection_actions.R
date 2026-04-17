#' Right-click selection actions
#'
#' These functions are invoked via RStudio's addin menu when the user has
#' selected code in the editor. They pre-populate the chat with a specific
#' prompt about the selected code.

#' Explain the selected code
#' @export
explain_selection <- function() {
  selection <- safe_get_selection()
  if (nchar(trimws(selection)) == 0) {
    rstudioapi::showDialog(
      "sparx",
      "Select some code first, then run this action."
    )
    return(invisible())
  }

  prompt <- glue::glue("Explain this R code in plain English, step by step:\n\n```r\n{selection}\n```")
  run_one_shot(prompt, title_suffix = "Explain")
}

#' Fix the selected code
#' @export
fix_selection <- function() {
  selection <- safe_get_selection()
  if (nchar(trimws(selection)) == 0) {
    rstudioapi::showDialog(
      "sparx",
      "Select some code first, then run this action."
    )
    return(invisible())
  }

  prompt <- glue::glue("This R code has a problem. Diagnose what's wrong and fix it:\n\n```r\n{selection}\n```")
  run_one_shot(prompt, title_suffix = "Fix")
}

#' Improve the selected code
#' @export
improve_selection <- function() {
  selection <- safe_get_selection()
  if (nchar(trimws(selection)) == 0) {
    rstudioapi::showDialog(
      "sparx",
      "Select some code first, then run this action."
    )
    return(invisible())
  }

  prompt <- glue::glue("Rewrite this R code to be more idiomatic, readable, and efficient. Explain what you changed:\n\n```r\n{selection}\n```")
  run_one_shot(prompt, title_suffix = "Improve")
}

#' Open the chat gadget with a pre-populated prompt
#'
#' Used by selection actions. The chat gadget opens, the user sees their
#' selection already in the textarea, and they click Send (or just Cmd+Enter).
#'
#' @keywords internal
run_one_shot <- function(prompt, title_suffix = "") {
  # Store the pre-populated prompt in a package-level env so open_chat reads it
  .sparx_state$pending_prompt <- prompt
  .sparx_state$title_suffix <- title_suffix
  open_chat()
}

# Package-level state for passing info between addin calls
.sparx_state <- new.env(parent = emptyenv())
.sparx_state$pending_prompt <- NULL
.sparx_state$title_suffix <- NULL
