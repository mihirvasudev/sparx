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
    # ── Data & session ──────────────────────────────────
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
    ),
    # ── File system ─────────────────────────────────────
    list(
      name = "list_files",
      description = paste0(
        "List files in the project matching a glob pattern. Returns relative ",
        "paths from the project root. Use to discover what's in the project ",
        "before reading or editing files. Examples of pattern: '*.R', ",
        "'data/*.csv', '**/*.Rmd' (recursive). Defaults to all files."
      ),
      input_schema = list(
        type = "object",
        properties = list(
          pattern = list(
            type = "string",
            description = "Glob pattern (default: '*')"
          ),
          recursive = list(
            type = "boolean",
            description = "Search subdirectories too (default: TRUE)"
          )
        ),
        required = list()
      )
    ),
    list(
      name = "read_file",
      description = paste0(
        "Read the contents of a file in the project. Only text files (R, Rmd, ",
        "qmd, csv, md, txt, json, yaml, etc.) are readable. Binary files are ",
        "refused. Returns file contents with line numbers. Use line_start/line_end ",
        "to read a specific range of a large file."
      ),
      input_schema = list(
        type = "object",
        properties = list(
          path = list(
            type = "string",
            description = "Path to file (relative to project root, or absolute inside root)"
          ),
          line_start = list(
            type = "integer",
            description = "Optional: first line to read"
          ),
          line_end = list(
            type = "integer",
            description = "Optional: last line to read"
          )
        ),
        required = list("path")
      )
    ),
    list(
      name = "grep_files",
      description = paste0(
        "Search file contents across the project for a regex pattern. Returns ",
        "matching files and matching lines with line numbers. Use this to find ",
        "where a function is defined, where a variable is used, etc."
      ),
      input_schema = list(
        type = "object",
        properties = list(
          pattern = list(
            type = "string",
            description = "Regex pattern to search for"
          ),
          file_glob = list(
            type = "string",
            description = "Optional: file glob to limit search (e.g., '*.R')"
          ),
          ignore_case = list(
            type = "boolean",
            description = "Case-insensitive match (default: FALSE)"
          )
        ),
        required = list("pattern")
      )
    ),
    list(
      name = "write_file",
      description = paste0(
        "Create or OVERWRITE a file in the project. Use sparingly — ONLY ",
        "for creating new files. For modifying existing files, prefer `edit_file` ",
        "which makes targeted changes instead of rewriting the whole file. ",
        "If the file exists, you MUST read it first with `read_file` before ",
        "overwriting it."
      ),
      input_schema = list(
        type = "object",
        properties = list(
          path = list(
            type = "string",
            description = "Path to file (relative to project root)"
          ),
          content = list(
            type = "string",
            description = "Full contents of the new file"
          )
        ),
        required = list("path", "content")
      )
    ),
    list(
      name = "inspect_plot",
      description = paste0(
        "Capture the current plot from the RStudio Plots pane and look at it ",
        "using vision. Use this AFTER the user has generated a plot, to ",
        "describe what it shows, critique the visualization, or suggest ",
        "improvements. Returns the plot image directly so you can see it."
      ),
      input_schema = list(
        type = "object",
        properties = list(),
        required = list()
      )
    ),
    list(
      name = "install_packages",
      description = paste0(
        "Install R packages from CRAN. Use this when your code needs a package ",
        "that isn't installed (check with check_package first). The user will ",
        "be asked to confirm before installation proceeds. After installation, ",
        "the user can call library() in their own code. Do not call library() ",
        "on behalf of the user."
      ),
      input_schema = list(
        type = "object",
        properties = list(
          packages = list(
            type = "array",
            items = list(type = "string"),
            description = "Package names to install (e.g., ['lme4', 'ggplot2'])"
          )
        ),
        required = list("packages")
      )
    ),
    list(
      name = "fetch_url",
      description = paste0(
        "Fetch a URL and return its text content (HTML tags stripped). Use ",
        "to read R package documentation, blog posts, Stack Overflow threads, ",
        "or API references the user mentions. Returns up to 8000 characters ",
        "of cleaned text. Refuses non-https URLs and binary content types."
      ),
      input_schema = list(
        type = "object",
        properties = list(
          url = list(
            type = "string",
            description = "HTTPS URL to fetch"
          )
        ),
        required = list("url")
      )
    ),
    list(
      name = "git_status",
      description = paste0(
        "Show the git status of the project (staged, modified, untracked ",
        "files). Use before suggesting commits or to understand what the ",
        "user is working on."
      ),
      input_schema = list(
        type = "object",
        properties = list(),
        required = list()
      )
    ),
    list(
      name = "git_diff",
      description = paste0(
        "Show the git diff for the project. Pass `staged = TRUE` to see ",
        "staged changes instead of working-tree changes. Optionally limit ",
        "to a specific file path."
      ),
      input_schema = list(
        type = "object",
        properties = list(
          path = list(
            type = "string",
            description = "Optional file path to limit the diff to"
          ),
          staged = list(
            type = "boolean",
            description = "Show staged changes (default: FALSE)"
          )
        ),
        required = list()
      )
    ),
    list(
      name = "git_log",
      description = paste0(
        "Show the recent git log (commit SHAs + messages). Use to understand ",
        "the history of the project or to see what's been done recently."
      ),
      input_schema = list(
        type = "object",
        properties = list(
          n = list(
            type = "integer",
            description = "Number of commits to show (default 10, max 50)"
          )
        ),
        required = list()
      )
    ),
    list(
      name = "run_in_session",
      description = paste0(
        "Execute R code in the USER'S LIVE R session (.GlobalEnv). Effects ",
        "persist — dataframes, variables, and loaded libraries will be visible ",
        "in RStudio's Environment pane afterwards. Use this for operations ",
        "the user needs to carry forward (loading data, transforming a ",
        "dataframe, fitting a model). Returns captured stdout/stderr and any ",
        "error message. ",
        "\n\n",
        "Blocked for safety: file deletion, system() calls, clearing the ",
        "environment (rm(list=ls())), and a few other destructive patterns. ",
        "For anything potentially destructive, explain it in the chat and let ",
        "the user click Run on a code block instead.",
        "\n\n",
        "Use `run_r_preview` first to verify the code works, THEN use ",
        "`run_in_session` to commit it to the user's session."
      ),
      input_schema = list(
        type = "object",
        properties = list(
          code = list(
            type = "string",
            description = "R code to execute in the live session"
          )
        ),
        required = list("code")
      )
    ),
    list(
      name = "get_session_state",
      description = paste0(
        "Get a summary of the current state of the user's R session: all ",
        "objects in .GlobalEnv (not just dataframes), their classes, and ",
        "shapes. Use this to check what variables exist after running code, ",
        "or to diagnose 'object not found' errors."
      ),
      input_schema = list(
        type = "object",
        properties = list(),
        required = list()
      )
    ),
    list(
      name = "todo_write",
      description = paste0(
        "Update a todo list visible to the user, tracking multi-step work. ",
        "Use this for tasks that take more than 2 tool calls. Each todo has a ",
        "status (pending/in_progress/completed). Only one should be in_progress ",
        "at a time. Call again as you progress to update status. The user sees ",
        "a checklist updating in real time."
      ),
      input_schema = list(
        type = "object",
        properties = list(
          todos = list(
            type = "array",
            items = list(
              type = "object",
              properties = list(
                content = list(type = "string", description = "Short task description"),
                status = list(type = "string", enum = list("pending", "in_progress", "completed"))
              ),
              required = list("content", "status")
            ),
            description = "Full list of todos (replaces existing list)"
          )
        ),
        required = list("todos")
      )
    ),
    list(
      name = "edit_file",
      description = paste0(
        "Make a targeted edit to an existing file. Finds `old_string` in the ",
        "file (must match exactly, including whitespace) and replaces it with ",
        "`new_string`. This is the PREFERRED way to modify existing files — ",
        "it preserves the rest of the file untouched. If `old_string` is not ",
        "unique in the file, the edit fails; include more surrounding context ",
        "in `old_string` to make it unique."
      ),
      input_schema = list(
        type = "object",
        properties = list(
          path = list(
            type = "string",
            description = "Path to file (relative to project root)"
          ),
          old_string = list(
            type = "string",
            description = "Exact text to find (include surrounding context to make it unique)"
          ),
          new_string = list(
            type = "string",
            description = "Replacement text"
          ),
          replace_all = list(
            type = "boolean",
            description = "Replace every occurrence (default: FALSE)"
          )
        ),
        required = list("path", "old_string", "new_string")
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
      "list_files" = tool_list_files(input$pattern %||% "*", input$recursive %||% TRUE),
      "read_file" = tool_read_file(input$path, input$line_start, input$line_end),
      "grep_files" = tool_grep_files(input$pattern, input$file_glob, input$ignore_case %||% FALSE),
      "write_file" = tool_write_file(input$path, input$content),
      "edit_file" = tool_edit_file(input$path, input$old_string, input$new_string, input$replace_all %||% FALSE),
      "inspect_plot" = tool_inspect_plot(),
      "install_packages" = tool_install_packages(input$packages),
      "todo_write" = tool_todo_write(input$todos),
      "run_in_session" = tool_run_in_session(input$code),
      "get_session_state" = tool_get_session_state(),
      "fetch_url" = tool_fetch_url(input$url),
      "git_status" = tool_git_status(),
      "git_diff" = tool_git_diff(input$path, input$staged %||% FALSE),
      "git_log" = tool_git_log(input$n %||% 10),
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

# ── File-system tools ──────────────────────────────────────────────────────

#' List project files matching a glob pattern
#' @keywords internal
tool_list_files <- function(pattern = "*", recursive = TRUE) {
  root <- find_project_root()

  # Convert glob → regex
  # Handle ** (recursive) as special case
  has_globstar <- grepl("**", pattern, fixed = TRUE)
  if (has_globstar) recursive <- TRUE

  simple_pattern <- gsub("\\*\\*/", "", pattern, fixed = FALSE)
  regex <- utils::glob2rx(simple_pattern)

  all_files <- list.files(
    root,
    pattern = regex,
    recursive = recursive,
    full.names = FALSE,
    include.dirs = FALSE,
    all.files = FALSE
  )

  # Exclude common noise
  all_files <- all_files[!grepl(
    "(^|/)(\\.Rproj\\.user|\\.git|\\.DS_Store|node_modules|renv|__pycache__|\\.venv)(/|$)",
    all_files
  )]

  if (length(all_files) == 0) {
    return(paste0("(no files matching '", pattern, "' in ", root, ")"))
  }

  # Truncate if huge
  if (length(all_files) > 200) {
    head_files <- utils::head(all_files, 200)
    paste0(
      "Project root: ", root, "\n",
      "Matched ", length(all_files), " files (showing first 200):\n",
      paste(head_files, collapse = "\n")
    )
  } else {
    paste0(
      "Project root: ", root, "\n",
      "Matched ", length(all_files), " files:\n",
      paste(all_files, collapse = "\n")
    )
  }
}

#' Read a project file
#' @keywords internal
tool_read_file <- function(path, line_start = NULL, line_end = NULL) {
  resolved <- resolve_project_path(path)
  if (is.null(resolved)) {
    return(paste0("ERROR: path `", path, "` is outside the project root or invalid."))
  }
  if (!file.exists(resolved)) {
    return(paste0("ERROR: file does not exist: ", relative_to_root(resolved)))
  }
  if (dir.exists(resolved)) {
    return(paste0("ERROR: `", relative_to_root(resolved), "` is a directory, not a file. Use list_files."))
  }
  if (!is_text_file(resolved)) {
    return(paste0("ERROR: `", relative_to_root(resolved), "` doesn't look like a text file (extension not supported)."))
  }

  size <- file.info(resolved)$size
  if (is.na(size) || size > 500000) {
    return(paste0("ERROR: file is too large (", size %||% "unknown", " bytes). Read a specific range with line_start/line_end."))
  }

  lines <- tryCatch(
    readLines(resolved, warn = FALSE),
    error = function(e) NULL
  )
  if (is.null(lines)) {
    return(paste0("ERROR: could not read ", relative_to_root(resolved)))
  }

  n <- length(lines)
  s <- max(1L, as.integer(line_start %||% 1L))
  e <- min(n, as.integer(line_end %||% n))

  if (s > n) {
    return(paste0("ERROR: line_start (", s, ") exceeds file length (", n, ")."))
  }

  selected <- lines[s:e]
  # Prefix with line numbers (Claude Code style)
  numbered <- sprintf("%5d\u2192%s", seq(s, e), selected)

  paste0(
    relative_to_root(resolved), " (lines ", s, "-", e, " of ", n, ")\n",
    paste(numbered, collapse = "\n")
  )
}

#' Search file contents for a regex pattern
#' @keywords internal
tool_grep_files <- function(pattern, file_glob = NULL, ignore_case = FALSE) {
  root <- find_project_root()

  # Build file list
  regex_glob <- if (!is.null(file_glob) && nzchar(file_glob)) {
    utils::glob2rx(file_glob)
  } else {
    NULL
  }

  all_files <- list.files(
    root,
    pattern = regex_glob,
    recursive = TRUE,
    full.names = TRUE,
    include.dirs = FALSE,
    all.files = FALSE
  )

  # Exclude noise + non-text
  all_files <- all_files[!grepl(
    "(^|/)(\\.Rproj\\.user|\\.git|\\.DS_Store|node_modules|renv|__pycache__|\\.venv)(/|$)",
    all_files
  )]
  all_files <- all_files[vapply(all_files, is_text_file, logical(1))]

  if (length(all_files) == 0) {
    return("(no files to search)")
  }

  # Search each file
  matches <- list()
  for (f in all_files) {
    lines <- tryCatch(readLines(f, warn = FALSE), error = function(e) NULL)
    if (is.null(lines) || length(lines) == 0) next

    hit_lines <- tryCatch(
      grep(pattern, lines, ignore.case = ignore_case, value = FALSE, perl = TRUE),
      error = function(e) integer()
    )
    if (length(hit_lines) > 0) {
      rel <- relative_to_root(f, root)
      matches[[rel]] <- data.frame(
        line = hit_lines,
        text = lines[hit_lines],
        stringsAsFactors = FALSE
      )
    }
  }

  if (length(matches) == 0) {
    return(paste0("No matches for pattern `", pattern, "`."))
  }

  # Format output
  out_lines <- character()
  total_hits <- 0
  for (rel_path in names(matches)) {
    hits <- matches[[rel_path]]
    for (i in seq_len(nrow(hits))) {
      if (total_hits >= 100) break
      out_lines <- c(out_lines, sprintf("%s:%d: %s", rel_path, hits$line[i], hits$text[i]))
      total_hits <- total_hits + 1
    }
    if (total_hits >= 100) break
  }

  header <- sprintf("Found %d matches in %d files%s",
                    sum(vapply(matches, nrow, integer(1))),
                    length(matches),
                    if (total_hits >= 100) " (showing first 100)" else "")
  paste(c(header, out_lines), collapse = "\n")
}

#' Write a new file (or overwrite an existing one)
#' @keywords internal
tool_write_file <- function(path, content) {
  if (is.null(path) || !nzchar(path)) {
    return("ERROR: path is required.")
  }
  if (is.null(content)) content <- ""

  resolved <- resolve_project_path(path)
  if (is.null(resolved)) {
    return(paste0("ERROR: path `", path, "` is outside the project root or invalid."))
  }

  # Create parent directory if needed
  parent <- dirname(resolved)
  if (!dir.exists(parent)) {
    dir.create(parent, recursive = TRUE, showWarnings = FALSE)
  }

  existed <- file.exists(resolved)
  tryCatch({
    writeLines(content, resolved, useBytes = TRUE)
  }, error = function(e) {
    stop("writeLines failed: ", conditionMessage(e))
  })

  action <- if (existed) "overwrote" else "created"
  n_lines <- length(strsplit(content, "\n", fixed = TRUE)[[1]])
  paste0("Successfully ", action, " ", relative_to_root(resolved),
         " (", n_lines, " lines, ", nchar(content), " chars).")
}

#' Make a targeted edit to an existing file
#'
#' Claude Code-style: exact-match find-and-replace. old_string must appear
#' uniquely unless replace_all=TRUE.
#'
#' @keywords internal
tool_edit_file <- function(path, old_string, new_string, replace_all = FALSE) {
  if (is.null(path) || !nzchar(path)) return("ERROR: path is required.")
  if (is.null(old_string)) return("ERROR: old_string is required.")
  if (is.null(new_string)) new_string <- ""

  resolved <- resolve_project_path(path)
  if (is.null(resolved)) {
    return(paste0("ERROR: path `", path, "` is outside the project root or invalid."))
  }
  if (!file.exists(resolved)) {
    return(paste0("ERROR: file does not exist: ", relative_to_root(resolved)))
  }
  if (!is_text_file(resolved)) {
    return(paste0("ERROR: `", relative_to_root(resolved), "` is not a text file."))
  }

  current <- tryCatch(
    paste(readLines(resolved, warn = FALSE), collapse = "\n"),
    error = function(e) NULL
  )
  if (is.null(current)) {
    return(paste0("ERROR: could not read ", relative_to_root(resolved)))
  }

  # Count matches
  n_matches <- length(gregexpr(old_string, current, fixed = TRUE)[[1]])
  if (n_matches == 1 && attr(gregexpr(old_string, current, fixed = TRUE)[[1]], "match.length")[1] == -1) {
    n_matches <- 0
  }

  if (n_matches == 0) {
    return(paste0(
      "ERROR: old_string not found in ", relative_to_root(resolved),
      ". Make sure the text matches exactly (including whitespace, newlines, and indentation)."
    ))
  }
  if (n_matches > 1 && !replace_all) {
    return(paste0(
      "ERROR: old_string matches ", n_matches, " times in ", relative_to_root(resolved),
      ". Either include more surrounding context to make the match unique, or pass replace_all=TRUE."
    ))
  }

  new_content <- if (replace_all) {
    gsub(old_string, new_string, current, fixed = TRUE)
  } else {
    sub(old_string, new_string, current, fixed = TRUE)
  }

  tryCatch({
    writeLines(new_content, resolved, useBytes = TRUE)
  }, error = function(e) {
    stop("writeLines failed: ", conditionMessage(e))
  })

  n_replaced <- if (replace_all) n_matches else 1L

  # Build a unified-ish diff for the UI to parse
  diff_text <- build_simple_diff(old_string, new_string)

  paste0(
    "Successfully edited ", relative_to_root(resolved),
    " (", n_replaced, " replacement", if (n_replaced != 1) "s" else "", ").",
    "\n\n<<<DIFF>>>\n", diff_text, "\n<<<END DIFF>>>"
  )
}

#' Build a simple line-based diff between two strings
#'
#' Not a full LCS algorithm — just marks old lines with "-" and new with "+".
#' Good enough for the UI to render color-coded +/- lines.
#' @keywords internal
build_simple_diff <- function(old_str, new_str) {
  old_lines <- strsplit(old_str, "\n", fixed = TRUE)[[1]]
  new_lines <- strsplit(new_str, "\n", fixed = TRUE)[[1]]
  out <- character()
  for (l in old_lines) out <- c(out, paste0("- ", l))
  for (l in new_lines) out <- c(out, paste0("+ ", l))
  paste(out, collapse = "\n")
}

# ── Plot capture, install, todo tools ──────────────────────────────────────

#' Capture the current plot as a base64-encoded PNG
#'
#' Returns a special marker the agent loop knows how to turn into a vision
#' content block. If no plot exists, returns an error string.
#' @keywords internal
tool_inspect_plot <- function() {
  if (!interactive() || is.null(dev.list())) {
    # Try RStudio viewer pane
    return("ERROR: no active plot. The user needs to generate a plot first (e.g., plot(x), ggplot(...)).")
  }

  tmp <- tempfile(fileext = ".png")
  result <- tryCatch({
    # Save the current plot to PNG via dev.copy
    suppressMessages({
      current_dev <- dev.cur()
      # Open a PNG device of reasonable size
      grDevices::png(tmp, width = 960, height = 720, res = 120)
      # Copy the current plot into the PNG device
      tryCatch({
        dev.set(current_dev)
        dev.copy(which = dev.list()[["png"]])
      }, error = function(e) NULL)
      dev.off()
      dev.set(current_dev)
    })

    if (!file.exists(tmp) || file.info(tmp)$size == 0) {
      return("ERROR: failed to capture the plot (device may not support copying).")
    }

    # Read + base64 encode
    bytes <- readBin(tmp, "raw", n = file.info(tmp)$size)
    encoded <- base64enc_raw(bytes)

    paste0(
      "<<<SPARX_IMAGE png>>>\n",
      encoded,
      "\n<<<END SPARX_IMAGE>>>"
    )
  }, error = function(e) {
    paste0("ERROR capturing plot: ", conditionMessage(e))
  }, finally = {
    if (file.exists(tmp)) unlink(tmp)
  })

  result
}

#' Simple base64 encoder for raw bytes (avoids adding a dep)
#' @keywords internal
base64enc_raw <- function(raw_bytes) {
  if (requireNamespace("base64enc", quietly = TRUE)) {
    return(base64enc::base64encode(raw_bytes))
  }
  # Fallback: use openssl if available (it's a soft dep of many pkgs)
  if (requireNamespace("openssl", quietly = TRUE)) {
    return(as.character(openssl::base64_encode(raw_bytes)))
  }
  # Last-resort: jsonlite has base64_enc
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    return(jsonlite::base64_enc(raw_bytes))
  }
  stop("No base64 encoder available. Install 'base64enc' or 'openssl'.")
}

#' Install R packages (with user approval)
#'
#' The approval flow is handled by the gadget UI — when install_packages is
#' called, the UI shows a prompt and only calls install.packages after the
#' user clicks Approve. This executor is invoked post-approval.
#'
#' For the unattended case (no UI), installation proceeds with a one-line
#' console log.
#' @keywords internal
tool_install_packages <- function(packages) {
  if (is.null(packages) || length(packages) == 0) {
    return("ERROR: no packages specified.")
  }
  if (!is.character(packages)) {
    packages <- unlist(packages)
  }

  # Track which were already installed
  already <- intersect(packages, rownames(utils::installed.packages()))
  to_install <- setdiff(packages, already)

  if (length(to_install) == 0) {
    return(paste0("All requested packages already installed: ",
                  paste(packages, collapse = ", "), "."))
  }

  # Approval gate: set state and wait for UI to pass a token back
  # Simple MVP: always proceed (opt-in by user setting a flag)
  auto_install <- getOption("sparx.auto_install", FALSE)

  if (!auto_install) {
    return(paste0(
      "Packages needing install: ", paste(to_install, collapse = ", "),
      ".\n\n",
      "The user has not enabled auto-install. Ask them to run ",
      "`options(sparx.auto_install = TRUE)` if they want sparx to install ",
      "packages automatically, or they can install manually with: ",
      "install.packages(c(\"", paste(to_install, collapse = "\", \""), "\"))"
    ))
  }

  # Proceed with install
  result <- tryCatch({
    utils::install.packages(to_install, repos = "https://cloud.r-project.org")
    installed_now <- intersect(to_install, rownames(utils::installed.packages()))
    failed <- setdiff(to_install, installed_now)
    if (length(failed) == 0) {
      paste0("Installed: ", paste(installed_now, collapse = ", "), ".")
    } else {
      paste0("Installed ", paste(installed_now, collapse = ", "),
             ". FAILED to install: ", paste(failed, collapse = ", "),
             ". The user can try installing these manually.")
    }
  }, error = function(e) {
    paste0("ERROR during install.packages: ", conditionMessage(e))
  })

  result
}

#' Update the todo list (multi-step task tracker)
#'
#' Stores todos in a package-level state so the UI can render them.
#' Returns a confirmation string.
#' @keywords internal
tool_todo_write <- function(todos) {
  if (is.null(todos) || length(todos) == 0) {
    .sparx_todo_state$items <- list()
    return("Todo list cleared.")
  }

  # Normalize to list-of-named-lists
  normalized <- lapply(todos, function(t) {
    list(
      content = as.character(t$content %||% ""),
      status = as.character(t$status %||% "pending")
    )
  })

  .sparx_todo_state$items <- normalized

  counts <- table(vapply(normalized, function(t) t$status, character(1)))
  summary_str <- paste(
    names(counts), "=", counts, collapse = ", "
  )
  paste0("Todo list updated (", length(normalized), " items: ", summary_str, ").")
}

# Package-level todo state (read by the UI)
.sparx_todo_state <- new.env(parent = emptyenv())
.sparx_todo_state$items <- list()

# ── Live-session execution ─────────────────────────────────────────────────

#' Patterns blocked from live execution (destructive)
#'
#' These are matched as regexes against the user's code. If any match, the
#' tool refuses to run and explains to Claude.
#' @keywords internal
DESTRUCTIVE_PATTERNS <- c(
  # File deletion
  "\\bfile\\.remove\\s*\\(",
  "\\bunlink\\s*\\(",
  "\\bfs::file_delete\\s*\\(",
  "\\bfs::dir_delete\\s*\\(",
  # Environment clearing
  "\\brm\\s*\\(\\s*list\\s*=\\s*ls\\b",
  # System shell
  "\\bsystem\\s*\\(",
  "\\bsystem2\\s*\\(",
  "\\bshell\\s*\\(",
  "\\bshell\\.exec\\s*\\(",
  # Network/source injection
  "\\bsource\\s*\\(\\s*[\"']http",
  "\\bdownload\\.file\\s*\\(",
  # Forced package ops
  "\\bremove\\.packages\\s*\\(",
  "\\bdevtools::install_local\\s*\\(",
  # User-account ops
  "\\bSys\\.setenv\\s*\\(",
  # DB destruction
  "\\bdbRemoveTable\\s*\\(",
  # RStudio-API code-injection
  "\\brstudioapi::(sendToConsole|executeCommand)\\s*\\("
)

#' Check code against the destructive blocklist
#'
#' @return Matched pattern if code is blocked, NULL if safe
#' @keywords internal
check_destructive_patterns <- function(code) {
  if (is.null(code) || !nzchar(code)) return(NULL)
  for (pat in DESTRUCTIVE_PATTERNS) {
    if (grepl(pat, code, perl = TRUE)) return(pat)
  }
  NULL
}

#' Execute R code in the user's live session (.GlobalEnv)
#'
#' Captures stdout, stderr, warnings, and errors. Code runs in .GlobalEnv,
#' so variable assignments and library() calls persist for the user.
#'
#' Blocked destructive patterns: see DESTRUCTIVE_PATTERNS.
#' Live execution is gated by options(sparx.live_execution = TRUE) — OFF by
#' default for safety. If disabled, returns an instruction message so Claude
#' can present the code for the user to Run manually.
#'
#' @keywords internal
tool_run_in_session <- function(code) {
  if (is.null(code) || !nzchar(code)) return("ERROR: code is required.")

  # Gate: user must opt in
  enabled <- getOption("sparx.live_execution", FALSE)
  if (!isTRUE(enabled)) {
    return(paste0(
      "Live execution is not enabled. The user has not opted in with ",
      "`options(sparx.live_execution = TRUE)`. Present the code as a ",
      "code block in your response so they can click Run themselves, ",
      "or ask them to enable live execution."
    ))
  }

  # Safety: check for destructive patterns
  matched <- check_destructive_patterns(code)
  if (!is.null(matched)) {
    return(paste0(
      "REFUSED: code contains a destructive pattern (", matched, "). ",
      "sparx will not run this in the user's live session. If they want ",
      "to run it, they should do so manually or outside sparx."
    ))
  }

  start <- Sys.time()

  # Use a dedicated env for capturing — avoids the <<- scope issue where
  # assignments inside withCallingHandlers don't reach the calling frame.
  capture_env <- new.env(parent = emptyenv())
  capture_env$output_lines <- character()
  capture_env$warnings <- character()
  capture_env$error <- NULL

  result <- tryCatch(
    withCallingHandlers(
      {
        captured <- utils::capture.output(
          eval(parse(text = code), envir = globalenv()),
          type = "output",
          split = FALSE
        )
        capture_env$output_lines <- c(capture_env$output_lines, captured)
        "ok"
      },
      warning = function(w) {
        capture_env$warnings <- c(capture_env$warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      },
      message = function(m) {
        msg <- sub("\n$", "", conditionMessage(m))
        capture_env$output_lines <- c(capture_env$output_lines, msg)
        invokeRestart("muffleMessage")
      }
    ),
    error = function(e) {
      capture_env$error <- conditionMessage(e)
      "error"
    }
  )

  duration <- round(as.numeric(Sys.time() - start, units = "secs"), 2)

  parts <- character()
  if (length(capture_env$output_lines) > 0) {
    out_text <- paste(capture_env$output_lines, collapse = "\n")
    if (nchar(out_text) > 4000) {
      out_text <- paste0(substr(out_text, 1, 4000), "\n... [truncated]")
    }
    parts <- c(parts, paste0("Output:\n", out_text))
  }
  if (length(capture_env$warnings) > 0) {
    parts <- c(parts,
      paste0("Warnings:\n- ", paste(capture_env$warnings, collapse = "\n- ")))
  }
  if (!is.null(capture_env$error)) {
    return(paste0("ERROR: ", capture_env$error, "\n(ran for ", duration, "s)"))
  }
  if (length(parts) == 0) {
    parts <- "(code ran successfully with no printed output)"
  }
  paste0(paste(parts, collapse = "\n\n"), "\n\n(ran in ", duration, "s; session state updated)")
}

# ── Web fetch ──────────────────────────────────────────────────────────────

#' Fetch a URL and return cleaned text content
#' @keywords internal
tool_fetch_url <- function(url) {
  if (is.null(url) || !nzchar(url)) return("ERROR: url is required.")

  # Security: require https
  if (!grepl("^https://", url)) {
    return("ERROR: only HTTPS URLs are allowed.")
  }

  resp <- tryCatch(
    httr2::req_perform(
      httr2::request(url) |>
        httr2::req_timeout(20) |>
        httr2::req_user_agent("sparx-rstudio-addin/0.6")
    ),
    error = function(e) NULL
  )

  if (is.null(resp)) {
    return(paste0("ERROR: could not fetch ", url))
  }

  status <- httr2::resp_status(resp)
  if (status >= 400) {
    return(paste0("ERROR: HTTP ", status, " fetching ", url))
  }

  content_type <- tolower(httr2::resp_content_type(resp) %||% "")
  if (!grepl("text|html|json|xml", content_type)) {
    return(paste0("ERROR: refusing non-text content type: ", content_type))
  }

  body <- tryCatch(
    httr2::resp_body_string(resp),
    error = function(e) NULL
  )
  if (is.null(body)) {
    return(paste0("ERROR: could not decode body for ", url))
  }

  # Strip HTML tags for readability (very simple; not a full parser)
  if (grepl("html", content_type)) {
    # Remove <script> and <style> blocks entirely
    body <- gsub("<script[^>]*>.*?</script>", "", body,
                 ignore.case = TRUE, perl = TRUE)
    body <- gsub("<style[^>]*>.*?</style>", "", body,
                 ignore.case = TRUE, perl = TRUE)
    # Remove all tags
    body <- gsub("<[^>]+>", "", body, perl = TRUE)
    # Collapse whitespace
    body <- gsub("[ \t]+", " ", body)
    body <- gsub("\n[\n\\s]*\n", "\n\n", body, perl = TRUE)
    body <- trimws(body)
  }

  # Truncate to a reasonable size
  max_chars <- 8000L
  if (nchar(body) > max_chars) {
    body <- paste0(substr(body, 1, max_chars), "\n\n... [truncated]")
  }

  paste0("URL: ", url, "\nContent-Type: ", content_type, "\n\n", body)
}

# ── Git tools ──────────────────────────────────────────────────────────────

#' Check that git is available and we're in a repo
#' @keywords internal
ensure_git <- function() {
  git <- Sys.which("git")
  if (nchar(git) == 0) {
    return("ERROR: `git` is not on PATH. Install it to use git tools.")
  }
  root <- find_project_root()
  if (!dir.exists(file.path(root, ".git"))) {
    # Walk up looking for .git (project may be inside a larger repo)
    cur <- root
    while (cur != dirname(cur)) {
      if (dir.exists(file.path(cur, ".git"))) break
      cur <- dirname(cur)
    }
    if (!dir.exists(file.path(cur, ".git"))) {
      return("ERROR: not inside a git repository.")
    }
    root <- cur
  }
  list(git = git, root = root)
}

#' Helper: run git and return trimmed stdout (or ERROR string)
#' @keywords internal
run_git <- function(args, root, git) {
  out <- tryCatch(
    system2(git, args = args, stdout = TRUE, stderr = TRUE),
    error = function(e) e$message
  )
  status <- attr(out, "status")
  if (!is.null(status) && status != 0) {
    return(paste0("ERROR: git ", paste(args, collapse = " "), " failed:\n",
                  paste(out, collapse = "\n")))
  }
  paste(out, collapse = "\n")
}

#' Git status
#' @keywords internal
tool_git_status <- function() {
  info <- ensure_git()
  if (is.character(info)) return(info)

  # cd into the repo via system2's wd
  old_wd <- setwd(info$root)
  on.exit(setwd(old_wd), add = TRUE)

  out <- run_git(c("status", "--short", "--branch"), info$root, info$git)
  if (nchar(out) == 0) return("Working tree clean.")
  out
}

#' Git diff
#' @keywords internal
tool_git_diff <- function(path = NULL, staged = FALSE) {
  info <- ensure_git()
  if (is.character(info)) return(info)

  old_wd <- setwd(info$root)
  on.exit(setwd(old_wd), add = TRUE)

  args <- c("diff")
  if (isTRUE(staged)) args <- c(args, "--staged")
  if (!is.null(path) && nzchar(path)) args <- c(args, "--", path)

  out <- run_git(args, info$root, info$git)

  # Truncate huge diffs
  if (nchar(out) > 6000) {
    out <- paste0(substr(out, 1, 6000), "\n... [diff truncated]")
  }
  if (nchar(out) == 0) {
    return(if (staged) "No staged changes." else "No working-tree changes.")
  }
  out
}

#' Git log (last N commits)
#' @keywords internal
tool_git_log <- function(n = 10) {
  info <- ensure_git()
  if (is.character(info)) return(info)

  old_wd <- setwd(info$root)
  on.exit(setwd(old_wd), add = TRUE)

  n <- min(max(1L, as.integer(n)), 50L)
  out <- run_git(
    c("log", paste0("-", n), "--oneline", "--decorate", "--no-color"),
    info$root, info$git
  )
  if (nchar(out) == 0) return("No commits yet.")
  out
}

#' Summarize the user's current .GlobalEnv
#'
#' Returns class, length/dim, and a short summary for each object.
#' @keywords internal
tool_get_session_state <- function() {
  obj_names <- ls(envir = .GlobalEnv)
  if (length(obj_names) == 0) {
    return("(.GlobalEnv is empty)")
  }

  lines <- character()
  for (n in obj_names) {
    obj <- tryCatch(get(n, envir = .GlobalEnv), error = function(e) NULL)
    if (is.null(obj)) next
    cls <- paste(class(obj), collapse = "/")
    shape <- tryCatch({
      if (is.data.frame(obj)) {
        paste0(nrow(obj), "x", ncol(obj), " df (cols: ",
               paste(utils::head(names(obj), 5), collapse = ","),
               if (ncol(obj) > 5) ",..." else "",
               ")")
      } else if (is.matrix(obj)) {
        paste0(nrow(obj), "x", ncol(obj), " matrix")
      } else if (is.list(obj)) {
        paste0("list, length ", length(obj))
      } else if (is.atomic(obj)) {
        if (length(obj) == 1) paste0("scalar: ", format(obj, trim = TRUE))
        else paste0("length ", length(obj))
      } else {
        paste0("class: ", cls)
      }
    }, error = function(e) cls)
    lines <- c(lines, sprintf("- %s <%s>: %s", n, cls, shape))
  }

  paste0(
    "Objects in .GlobalEnv (", length(obj_names), "):\n",
    paste(lines, collapse = "\n")
  )
}
