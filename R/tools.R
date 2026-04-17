#' Tool definitions and executors
#'
#' sparx gives Claude a set of tools to operate on the user's R session.
#' These follow the Anthropic tool-use schema: each tool has a name,
#' description, input_schema (JSON Schema), and a local executor function.
#'
#' Design principles:
#' - Tools are safe by default. Destructive ops (file deletion, overwriting)
#'   are explicitly excluded or gated.
#' - Tools that touch the user's live session (insert_code, run_in_console)
#'   are clearly separated from sandboxed ones (run_r_preview).
#' - Every tool returns a string — the human/machine-readable result that
#'   gets fed back to Claude as a tool_result.

# ── Tool schemas (sent to Claude) ──────────────────────────────────────────

#' Anthropic-format tool definitions
#'
#' @return List of tool definitions to pass in the `tools` field of the API call
#' @keywords internal
tool_definitions <- function() {
  list(
    list(
      name = "inspect_data",
      description = paste0(
        "Inspect a dataframe in the user's R session. Returns column names, ",
        "types, a random sample of rows, and summary statistics. Use this ",
        "BEFORE writing any analysis code that depends on the structure of ",
        "a dataframe."
      ),
      input_schema = list(
        type = "object",
        properties = list(
          name = list(
            type = "string",
            description = "The dataframe variable name (as it appears in .GlobalEnv)"
          ),
          n_sample = list(
            type = "integer",
            description = "Number of sample rows to include (default 5, max 20)"
          )
        ),
        required = list("name")
      )
    ),
    list(
      name = "run_r_preview",
      description = paste0(
        "Execute R code in an ISOLATED subprocess (not the user's live session). ",
        "The code has access to a snapshot of the user's dataframes but any ",
        "side effects are discarded. Use this to VERIFY code works before ",
        "suggesting the user run it. Returns stdout, stderr, and execution time. ",
        "Code that needs packages will attempt to load them from the user's library."
      ),
      input_schema = list(
        type = "object",
        properties = list(
          code = list(
            type = "string",
            description = "R code to execute (can be multiple lines)"
          ),
          timeout_sec = list(
            type = "integer",
            description = "Seconds before killing the subprocess (default 30, max 120)"
          )
        ),
        required = list("code")
      )
    ),
    list(
      name = "check_package",
      description = paste0(
        "Check whether an R package is installed in the user's library. ",
        "Returns installed=TRUE/FALSE and version if installed. Use this ",
        "before writing code that depends on a package you're not sure is available."
      ),
      input_schema = list(
        type = "object",
        properties = list(
          package = list(
            type = "string",
            description = "The package name (e.g., 'lme4', 'ggplot2')"
          )
        ),
        required = list("package")
      )
    ),
    list(
      name = "read_editor",
      description = paste0(
        "Read lines from the user's currently-active editor document. ",
        "Use this to see the full script when the initial context (first 4K ",
        "chars) was truncated, or to look at a specific function."
      ),
      input_schema = list(
        type = "object",
        properties = list(
          line_start = list(
            type = "integer",
            description = "First line to read (1-indexed)"
          ),
          line_end = list(
            type = "integer",
            description = "Last line to read (inclusive). Omit to read to end."
          )
        ),
        required = list("line_start")
      )
    )
  )
}

# ── Tool executors (local) ─────────────────────────────────────────────────

#' Dispatch a tool call to the appropriate executor
#'
#' @param name Tool name
#' @param input Parsed input (named list)
#' @return Character scalar with the result, formatted for Claude to read
#'
#' @keywords internal
execute_tool <- function(name, input) {
  tryCatch({
    switch(
      name,
      "inspect_data" = tool_inspect_data(input$name, input$n_sample %||% 5),
      "run_r_preview" = tool_run_r_preview(input$code, input$timeout_sec %||% 30),
      "check_package" = tool_check_package(input$package),
      "read_editor" = tool_read_editor(input$line_start, input$line_end),
      paste0("ERROR: unknown tool `", name, "`")
    )
  }, error = function(e) {
    paste0("ERROR executing `", name, "`: ", conditionMessage(e))
  })
}

#' Inspect a dataframe
#' @keywords internal
tool_inspect_data <- function(name, n_sample = 5) {
  if (!exists(name, envir = .GlobalEnv, inherits = FALSE)) {
    return(paste0("ERROR: no object named `", name, "` in the global environment."))
  }
  obj <- get(name, envir = .GlobalEnv)
  if (!is.data.frame(obj)) {
    return(paste0("ERROR: `", name, "` is not a dataframe (class: ",
                  paste(class(obj), collapse = ","), ")."))
  }

  n_sample <- min(as.integer(n_sample), 20L, nrow(obj))

  col_info <- lapply(names(obj), function(col) {
    x <- obj[[col]]
    list(
      name = col,
      type = paste(class(x), collapse = ","),
      n_unique = tryCatch(length(unique(x)), error = function(e) NA),
      n_missing = sum(is.na(x)),
      example = tryCatch(
        paste(utils::head(stats::na.omit(as.character(x)), 3), collapse = ", "),
        error = function(e) ""
      )
    )
  })

  col_lines <- sapply(col_info, function(c) {
    sprintf("  - %s <%s>: %d unique, %d missing, examples: %s",
            c$name, c$type, c$n_unique, c$n_missing, c$example)
  })

  sample_text <- tryCatch({
    sample_rows <- obj[sample(nrow(obj), n_sample, replace = FALSE), , drop = FALSE]
    paste(utils::capture.output(print(sample_rows)), collapse = "\n")
  }, error = function(e) "(could not sample rows)")

  paste0(
    "Dataframe `", name, "`: ", nrow(obj), " rows x ", ncol(obj), " columns.\n\n",
    "Columns:\n",
    paste(col_lines, collapse = "\n"),
    "\n\nSample rows (n=", n_sample, "):\n",
    sample_text
  )
}

#' Execute R code in an isolated subprocess
#'
#' Uses callr::r() so we inherit the user's package library but get an
#' isolated state. Any side effects are discarded.
#'
#' @keywords internal
tool_run_r_preview <- function(code, timeout_sec = 30) {
  timeout_sec <- min(as.integer(timeout_sec), 120L)

  # Snapshot dataframes from user's global env so the preview sees them
  df_names <- character()
  for (n in ls(envir = .GlobalEnv)) {
    if (is.data.frame(tryCatch(get(n, envir = .GlobalEnv), error = function(e) NULL))) {
      df_names <- c(df_names, n)
    }
  }
  # Take up to 3 dataframes (serialization cost)
  df_names <- utils::head(df_names, 3)

  snapshot <- list()
  for (n in df_names) {
    snapshot[[n]] <- get(n, envir = .GlobalEnv)
  }

  # Run in subprocess
  result <- tryCatch({
    if (!requireNamespace("callr", quietly = TRUE)) {
      # Fallback: eval in main session with capture (less safe, but works)
      output <- utils::capture.output({
        eval(parse(text = code), envir = new.env(parent = globalenv()))
      }, type = "output")
      list(output = paste(output, collapse = "\n"), error = NULL, duration = NA)
    } else {
      start <- Sys.time()
      res <- callr::r(
        function(code, snapshot) {
          for (nm in names(snapshot)) {
            assign(nm, snapshot[[nm]], envir = globalenv())
          }
          out <- utils::capture.output({
            eval(parse(text = code), envir = globalenv())
          }, type = "output")
          list(output = paste(out, collapse = "\n"))
        },
        args = list(code = code, snapshot = snapshot),
        timeout = timeout_sec,
        error = "error"
      )
      duration <- as.numeric(Sys.time() - start)
      list(output = res$output %||% "", error = NULL, duration = duration)
    }
  }, error = function(e) {
    list(output = "", error = conditionMessage(e), duration = NA)
  })

  # Format for Claude
  out <- if (nchar(result$output) > 0) result$output else "(no output)"
  err <- if (!is.null(result$error)) paste0("\nERROR: ", result$error) else ""
  dur <- if (!is.na(result$duration)) sprintf("\n(ran in %.2fs)", result$duration) else ""

  # Truncate output if huge
  if (nchar(out) > 4000) out <- paste0(substr(out, 1, 4000), "\n... [truncated]")

  paste0("Output:\n", out, err, dur)
}

#' Check if a package is installed
#' @keywords internal
tool_check_package <- function(package) {
  installed <- package %in% rownames(utils::installed.packages())
  if (installed) {
    ver <- tryCatch(
      as.character(utils::packageVersion(package)),
      error = function(e) "unknown"
    )
    paste0("`", package, "` is installed (version ", ver, ").")
  } else {
    paste0("`", package, "` is NOT installed. The user can install it with ",
           "`install.packages(\"", package, "\")` if they choose to.")
  }
}

#' Read lines from the active editor
#' @keywords internal
tool_read_editor <- function(line_start, line_end = NULL) {
  ctx <- tryCatch(
    rstudioapi::getSourceEditorContext(),
    error = function(e) NULL
  )
  if (is.null(ctx)) return("ERROR: no active editor document.")

  lines <- ctx$contents
  n <- length(lines)
  line_start <- max(1, as.integer(line_start))
  line_end <- if (is.null(line_end) || is.na(line_end)) n else min(n, as.integer(line_end))

  if (line_start > n) {
    return(paste0("ERROR: line_start (", line_start, ") exceeds document length (", n, ")."))
  }

  selected <- lines[line_start:line_end]
  paste0(
    "Lines ", line_start, "-", line_end, " of ", n, " from ",
    ctx$path %||% "<unsaved>", ":\n\n",
    paste(selected, collapse = "\n")
  )
}
