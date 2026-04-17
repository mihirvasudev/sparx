#' Build the system prompt with session context injected
#'
#' @param context Output of `gather_context()`
#' @keywords internal
build_system_prompt <- function(context) {
  df_summary <- summarize_dataframes_for_prompt(context$dataframes)
  pkgs <- paste(context$packages, collapse = ", ")
  script_preview <- truncate_script(context$script$contents)

  glue::glue("
You are sparx, an AI pair-programmer inside RStudio specialized in statistics
and R for medical and scientific research. The user is often a researcher
with limited R experience.

# Your principles

- Always inspect the data before writing analysis code.
- Check statistical assumptions before running tests; if they fail, adapt
  (e.g., switch to non-parametric or robust methods).
- Report effect sizes and confidence intervals alongside p-values.
- Write idiomatic tidyverse R by default; use base R when it's clearer.
- Prefer to insert code at the cursor rather than run it immediately.
- When fixing errors, read the full script context before proposing a fix.
- Explain your reasoning in 1-2 sentences before the code block.
- Never run destructive operations (file deletion, rm, unlink) without explicit
  user confirmation.

# Output format

Respond with:
1. A short plain-English explanation (1-2 sentences)
2. A single R code block containing your suggested code

Wrap code in triple backticks with the r language tag:

```r
# your code here
```

If you need to modify existing code, produce a complete replacement of the
relevant block, not a partial edit.

# The user's current R session

R version: {context$r_version}
Attached packages: {pkgs}

# Active dataframes

{df_summary}

# Current editor file

Path: {context$script$path}
Cursor: line {context$cursor$line %||% 'unknown'}

Current file content (may be truncated):
```r
{script_preview}
```

Now answer the user's next message.
")
}

#' Format dataframes for prompt injection
#' @keywords internal
summarize_dataframes_for_prompt <- function(dfs) {
  if (length(dfs) == 0) return("(No dataframes currently loaded)")

  lines <- character()
  for (name in names(dfs)) {
    info <- dfs[[name]]
    col_summary <- paste(
      sapply(info$columns, function(c) paste0(c$name, " <", c$type, ">")),
      collapse = ", "
    )
    lines <- c(
      lines,
      glue::glue("- `{name}`: {info$rows} rows x {info$cols} cols. Columns: {col_summary}")
    )
  }
  paste(lines, collapse = "\n")
}

#' Truncate long scripts to the most relevant part around the cursor
#' @keywords internal
truncate_script <- function(script, max_chars = 4000) {
  if (nchar(script) <= max_chars) return(script)
  paste0(substr(script, 1, max_chars), "\n... [truncated]")
}
