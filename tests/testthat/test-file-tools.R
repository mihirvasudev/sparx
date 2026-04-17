#' Tests for file-system tools.
#'
#' We use a temporary directory as a fake project root to avoid touching
#' real files and to ensure the sandbox (resolve_project_path) works.

setup_temp_project <- function() {
  td <- tempfile("sparx_test_")
  dir.create(td)
  # Mark as project root
  writeLines(
    "Package: test\nType: Package\nVersion: 0.0.1",
    file.path(td, "DESCRIPTION")
  )
  # Create some content files
  dir.create(file.path(td, "R"))
  writeLines(c(
    "hello <- function() {",
    "  message('hi')",
    "}",
    "",
    "add <- function(a, b) {",
    "  a + b",
    "}"
  ), file.path(td, "R", "hello.R"))
  writeLines(c("# Test Project", "", "Some notes here."), file.path(td, "README.md"))
  td
}

# Helper: stub find_project_root to use a temp dir for the test.
# Uses substitute() to delay evaluation of expr until after the stub is in place.
with_temp_project <- function(expr) {
  td <- setup_temp_project()
  expr_unevaluated <- substitute(expr)
  parent <- parent.frame()

  # Install stub in .GlobalEnv so tool functions (which live in .GlobalEnv when
  # we source the package manually) find it before their own definition.
  stub <- function() td
  prior_value <- if (exists("find_project_root", envir = globalenv(), inherits = FALSE)) {
    get("find_project_root", envir = globalenv())
  } else {
    NULL
  }
  assign("find_project_root", stub, envir = globalenv())

  on.exit({
    if (!is.null(prior_value)) {
      assign("find_project_root", prior_value, envir = globalenv())
    } else {
      suppressWarnings(rm("find_project_root", envir = globalenv()))
    }
    unlink(td, recursive = TRUE)
  }, add = TRUE)

  eval(expr_unevaluated, envir = parent)
}

test_that("list_files returns project files", {
  with_temp_project({
    result <- tool_list_files("*", recursive = TRUE)
    expect_type(result, "character")
    expect_match(result, "DESCRIPTION")
    expect_match(result, "README.md")
    expect_match(result, "R/hello\\.R")
  })
})

test_that("list_files respects the pattern", {
  with_temp_project({
    result <- tool_list_files("*.md", recursive = TRUE)
    expect_match(result, "README.md")
    expect_false(grepl("DESCRIPTION", result))
  })
})

test_that("read_file reads an existing file with line numbers", {
  with_temp_project({
    result <- tool_read_file("R/hello.R")
    expect_match(result, "hello <- function")
    expect_match(result, "1\u2192")  # line number arrow
  })
})

test_that("read_file errors for non-existent files", {
  with_temp_project({
    result <- tool_read_file("does_not_exist.R")
    expect_match(result, "ERROR")
  })
})

test_that("read_file refuses directory traversal", {
  with_temp_project({
    result <- tool_read_file("../../../etc/passwd")
    expect_match(result, "ERROR")
  })
})

test_that("read_file supports line_start/line_end", {
  with_temp_project({
    result <- tool_read_file("R/hello.R", line_start = 1, line_end = 2)
    expect_match(result, "hello <- function")
    expect_false(grepl("add <- function", result))
  })
})

test_that("grep_files finds matching lines", {
  with_temp_project({
    result <- tool_grep_files("function\\(", file_glob = "*.R")
    expect_match(result, "hello\\.R:")
    expect_match(result, "Found")
  })
})

test_that("grep_files returns 'no matches' cleanly", {
  with_temp_project({
    result <- tool_grep_files("unlikely_string_xyz_12345")
    expect_match(result, "No matches")
  })
})

test_that("write_file creates a new file", {
  with_temp_project({
    result <- tool_write_file("new_script.R", "x <- 42")
    expect_match(result, "created")
    root <- find_project_root()
    expect_true(file.exists(file.path(root, "new_script.R")))
    content <- readLines(file.path(root, "new_script.R"))
    expect_equal(content, "x <- 42")
  })
})

test_that("write_file rejects paths outside project root", {
  with_temp_project({
    result <- tool_write_file("../escape_attempt.R", "malicious")
    expect_match(result, "ERROR")
  })
})

test_that("edit_file replaces a unique match", {
  with_temp_project({
    result <- tool_edit_file(
      "R/hello.R",
      old_string = "message('hi')",
      new_string = "message('hello world')"
    )
    expect_match(result, "Successfully edited")
    content <- paste(readLines(file.path(find_project_root(), "R/hello.R")), collapse = "\n")
    expect_match(content, "hello world")
    expect_false(grepl("'hi'", content))
  })
})

test_that("edit_file fails when old_string is not unique", {
  with_temp_project({
    result <- tool_edit_file(
      "R/hello.R",
      old_string = "function",  # appears 2x
      new_string = "lambda"
    )
    expect_match(result, "matches.*times")
  })
})

test_that("edit_file with replace_all=TRUE handles multiple matches", {
  with_temp_project({
    result <- tool_edit_file(
      "R/hello.R",
      old_string = "function",
      new_string = "lambda",
      replace_all = TRUE
    )
    expect_match(result, "Successfully edited")
  })
})

test_that("edit_file errors when old_string is not found", {
  with_temp_project({
    result <- tool_edit_file(
      "R/hello.R",
      old_string = "this string absolutely does not exist xyz123",
      new_string = "replacement"
    )
    expect_match(result, "not found")
  })
})

test_that("is_tool_error detects error markers", {
  expect_true(is_tool_error("ERROR: bad input"))
  expect_true(is_tool_error("ERROR executing foo: thing"))
  expect_false(is_tool_error("Successfully created file"))
  expect_false(is_tool_error("Dataframe has 100 rows"))
  expect_false(is_tool_error(NULL))
})

test_that("resolve_project_path rejects escapes", {
  with_temp_project({
    root <- find_project_root()
    expect_null(resolve_project_path("../etc/passwd", root = root))
    expect_null(resolve_project_path("/etc/passwd", root = root))
    # But in-project paths work
    expect_true(grepl("hello\\.R$",
                     resolve_project_path("R/hello.R", root = root)))
  })
})
