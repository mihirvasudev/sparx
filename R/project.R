#' Project root detection + path helpers
#'
#' All file operations are scoped to the "project root" — the nearest directory
#' containing an `.Rproj` file, a `.git` directory, a `DESCRIPTION` file, or
#' (as fallback) the current working directory.
#'
#' File paths passed to tools must be RELATIVE to the project root, or absolute
#' paths that resolve inside the root. Paths outside the root are rejected to
#' prevent the agent from reading sensitive files elsewhere on disk.

#' Find the project root directory
#'
#' Looks upward from the active editor's file, then RStudio's active project,
#' then `getwd()`. Stops at the first directory containing `.Rproj`, `.git`,
#' `DESCRIPTION`, or the user's home directory.
#'
#' @return Absolute path to the project root
#' @keywords internal
find_project_root <- function() {
  # 1. RStudio's active project
  active_proj <- tryCatch(
    rstudioapi::getActiveProject(),
    error = function(e) NULL
  )
  if (!is.null(active_proj) && nzchar(active_proj) && dir.exists(active_proj)) {
    return(normalizePath(active_proj, mustWork = FALSE))
  }

  # 2. Walk up from the active editor's document
  ctx <- tryCatch(rstudioapi::getSourceEditorContext(), error = function(e) NULL)
  start_dir <- if (!is.null(ctx) && nzchar(ctx$path %||% "")) {
    dirname(ctx$path)
  } else {
    getwd()
  }

  # Walk up looking for markers
  markers <- c(".Rproj", ".git", "DESCRIPTION")
  cur <- normalizePath(start_dir, mustWork = FALSE)
  home <- normalizePath("~", mustWork = FALSE)

  while (cur != dirname(cur) && cur != home) {
    files <- list.files(cur, all.files = TRUE, include.dirs = TRUE)
    has_rproj <- any(grepl("\\.Rproj$", files))
    if (has_rproj || ".git" %in% files || "DESCRIPTION" %in% files) {
      return(cur)
    }
    cur <- dirname(cur)
  }

  # Fallback: getwd()
  normalizePath(getwd(), mustWork = FALSE)
}

#' Resolve a user-supplied path against the project root
#'
#' Ensures the final path is within the project root (no `..` traversal
#' escapes, no absolute paths outside root). Returns NULL if the path
#' would escape the project.
#'
#' @param path User-supplied path (relative or absolute)
#' @param root Project root (from find_project_root)
#' @return Normalized absolute path, or NULL if out of bounds
#' @keywords internal
resolve_project_path <- function(path, root = NULL) {
  if (is.null(root)) root <- find_project_root()

  if (is.null(path) || !nzchar(path)) return(NULL)

  # Normalize root first — resolves symlinks (e.g. /var → /private/var on macOS)
  root_norm <- normalizePath(root, mustWork = FALSE, winslash = "/")

  # If absolute, use as-is; else join with normalized root so both sides
  # agree on symlink resolution
  full <- if (grepl("^(/|[A-Za-z]:[\\\\/])", path)) {
    path
  } else {
    file.path(root_norm, path)
  }

  # Resolve .. traversal by normalizing from an existing ancestor directory.
  # For paths to files that don't yet exist, normalizePath() leaves them
  # un-resolved, so we walk up to the first extant directory and normalize that.
  normalized <- resolve_with_missing_tail(full)

  # Must be within root
  if (!startsWith(normalized, paste0(root_norm, "/")) && normalized != root_norm) {
    return(NULL)
  }

  normalized
}

#' Normalize a path even if leaf components don't exist yet
#'
#' `normalizePath(mustWork = FALSE)` will not resolve symlinks for components
#' past the first missing one. This walks up to the first existing ancestor,
#' normalizes it, then rebuilds the full path.
#' @keywords internal
resolve_with_missing_tail <- function(path) {
  path <- gsub("\\\\", "/", path)
  # Quickly try: does it exist? Then normalize directly
  if (file.exists(path) || dir.exists(path)) {
    return(normalizePath(path, mustWork = FALSE, winslash = "/"))
  }
  parts <- strsplit(path, "/", fixed = TRUE)[[1]]
  tail <- character()
  while (length(parts) > 0) {
    candidate <- paste(parts, collapse = "/")
    if (candidate == "") candidate <- "/"
    if (dir.exists(candidate) || file.exists(candidate)) {
      base <- normalizePath(candidate, mustWork = FALSE, winslash = "/")
      if (length(tail) == 0) return(base)
      return(paste0(base, "/", paste(rev(tail), collapse = "/")))
    }
    tail <- c(tail, parts[length(parts)])
    parts <- parts[-length(parts)]
  }
  # Whole path is rootless / relative — fallback
  normalizePath(path, mustWork = FALSE, winslash = "/")
}

#' Check if a file extension indicates a text (non-binary) file
#' @keywords internal
is_text_file <- function(path) {
  if (dir.exists(path)) return(FALSE)
  ext <- tolower(tools::file_ext(path))
  text_exts <- c(
    "r", "rmd", "qmd", "py", "sql", "md", "txt", "csv", "tsv", "json",
    "yaml", "yml", "toml", "ini", "cfg", "conf", "xml", "html", "htm",
    "css", "js", "ts", "jsx", "tsx", "sh", "bash", "dcf", "rnw", "rproj",
    "log", "tex", "bib", ""
  )
  ext %in% text_exts
}

#' Path relative to project root (for nicer display)
#' @keywords internal
relative_to_root <- function(path, root = NULL) {
  if (is.null(root)) root <- find_project_root()
  root_norm <- normalizePath(root, mustWork = FALSE, winslash = "/")
  path_norm <- normalizePath(path, mustWork = FALSE, winslash = "/")
  if (startsWith(path_norm, paste0(root_norm, "/"))) {
    substring(path_norm, nchar(root_norm) + 2)
  } else {
    path_norm
  }
}
