test_that("save_conversation / load_conversation roundtrip", {
  td <- tempfile("sparx_persist_test_")
  dir.create(td)
  writeLines("Package: test", file.path(td, "DESCRIPTION"))
  on.exit(unlink(td, recursive = TRUE), add = TRUE)

  stub <- function() td
  assign("find_project_root", stub, envir = globalenv())
  on.exit(suppressWarnings(rm("find_project_root", envir = globalenv())), add = TRUE)

  msgs <- list(
    list(role = "user", content = "Hello"),
    list(role = "assistant", content = list(
      list(type = "text", text = "Hi there!")
    ))
  )
  todos <- list(list(content = "Task 1", status = "pending"))

  expect_true(save_conversation(msgs, todos))

  loaded <- load_conversation()
  expect_false(is.null(loaded))
  expect_length(loaded$messages, 2)
  expect_equal(loaded$messages[[1]]$role, "user")
  expect_equal(loaded$messages[[1]]$content, "Hello")
  expect_equal(loaded$todos[[1]]$content, "Task 1")
})

test_that("save_conversation writes .gitignore", {
  td <- tempfile("sparx_persist_gi_")
  dir.create(td)
  writeLines("Package: test", file.path(td, "DESCRIPTION"))
  on.exit(unlink(td, recursive = TRUE), add = TRUE)

  stub <- function() td
  assign("find_project_root", stub, envir = globalenv())
  on.exit(suppressWarnings(rm("find_project_root", envir = globalenv())), add = TRUE)

  save_conversation(list(list(role = "user", content = "x")))

  sparx_dir <- file.path(td, ".sparx")
  expect_true(dir.exists(sparx_dir))
  expect_true(file.exists(file.path(sparx_dir, ".gitignore")))
})

test_that("load_conversation returns NULL when nothing saved", {
  td <- tempfile("sparx_persist_empty_")
  dir.create(td)
  writeLines("Package: test", file.path(td, "DESCRIPTION"))
  on.exit(unlink(td, recursive = TRUE), add = TRUE)

  stub <- function() td
  assign("find_project_root", stub, envir = globalenv())
  on.exit(suppressWarnings(rm("find_project_root", envir = globalenv())), add = TRUE)

  expect_null(load_conversation())
})

test_that("clear_saved_conversation removes the file", {
  td <- tempfile("sparx_persist_clear_")
  dir.create(td)
  writeLines("Package: test", file.path(td, "DESCRIPTION"))
  on.exit(unlink(td, recursive = TRUE), add = TRUE)

  stub <- function() td
  assign("find_project_root", stub, envir = globalenv())
  on.exit(suppressWarnings(rm("find_project_root", envir = globalenv())), add = TRUE)

  save_conversation(list(list(role = "user", content = "x")))
  path <- conversation_file_path()
  expect_true(file.exists(path))

  clear_saved_conversation()
  expect_false(file.exists(path))
})

test_that("fetch_url refuses non-https URLs", {
  expect_match(tool_fetch_url("http://example.com"), "HTTPS")
  expect_match(tool_fetch_url("ftp://example.com"), "HTTPS")
  expect_match(tool_fetch_url(""), "required")
})

test_that("git_status returns sensible output in a non-repo directory", {
  skip_if(nchar(Sys.which("git")) == 0, "git not on PATH")

  td <- tempfile("sparx_git_test_")
  dir.create(td)
  on.exit(unlink(td, recursive = TRUE), add = TRUE)

  stub <- function() td
  assign("find_project_root", stub, envir = globalenv())
  on.exit(suppressWarnings(rm("find_project_root", envir = globalenv())), add = TRUE)

  result <- tool_git_status()
  expect_match(result, "not inside a git repository|ERROR")
})

test_that("tool_definitions includes all v0.6 tools", {
  tools <- tool_definitions()
  names <- vapply(tools, function(t) t$name, character(1))
  for (n in c("fetch_url", "git_status", "git_diff", "git_log")) {
    expect_true(n %in% names, info = paste("missing:", n))
  }
})

test_that("total tool count is now at 18+", {
  tools <- tool_definitions()
  expect_gte(length(tools), 18)
})
