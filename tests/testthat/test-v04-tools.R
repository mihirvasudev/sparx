test_that("todo_write stores todos in package state", {
  result <- tool_todo_write(list(
    list(content = "Inspect data", status = "in_progress"),
    list(content = "Write model", status = "pending"),
    list(content = "Verify code", status = "pending")
  ))
  expect_match(result, "updated")
  expect_length(.sparx_todo_state$items, 3)
  expect_equal(.sparx_todo_state$items[[1]]$content, "Inspect data")
  expect_equal(.sparx_todo_state$items[[1]]$status, "in_progress")
})

test_that("todo_write with empty list clears", {
  # Setup: put something in first
  .sparx_todo_state$items <- list(list(content = "x", status = "pending"))
  expect_length(.sparx_todo_state$items, 1)

  result <- tool_todo_write(list())
  expect_match(result, "cleared")
  expect_length(.sparx_todo_state$items, 0)
})

test_that("install_packages respects sparx.auto_install=FALSE", {
  old_opt <- getOption("sparx.auto_install")
  on.exit(options(sparx.auto_install = old_opt), add = TRUE)
  options(sparx.auto_install = FALSE)

  result <- tool_install_packages(c("zzzzunlikely_package"))
  # Should refuse and explain
  expect_match(result, "install\\.packages|auto_install")
})

test_that("install_packages reports when already installed", {
  old_opt <- getOption("sparx.auto_install")
  on.exit(options(sparx.auto_install = old_opt), add = TRUE)
  options(sparx.auto_install = TRUE)

  # stats is always installed
  result <- tool_install_packages(c("stats"))
  expect_match(result, "already installed")
})

test_that("build_simple_diff produces +/- lines", {
  diff <- build_simple_diff("old line one\nold line two", "new line")
  expect_match(diff, "- old line one")
  expect_match(diff, "- old line two")
  expect_match(diff, "\\+ new line")
})

test_that("edit_file result includes DIFF marker", {
  td <- tempfile("sparx_edit_test_")
  dir.create(td)
  on.exit(unlink(td, recursive = TRUE), add = TRUE)
  writeLines("Package: test", file.path(td, "DESCRIPTION"))

  test_file <- file.path(td, "a.txt")
  writeLines(c("hello world", "goodbye world"), test_file)

  # Stub find_project_root
  stub <- function() td
  assign("find_project_root", stub, envir = globalenv())
  on.exit({
    suppressWarnings(rm("find_project_root", envir = globalenv()))
  }, add = TRUE)

  result <- tool_edit_file("a.txt", "hello world", "hi there")
  expect_match(result, "Successfully edited")
  expect_match(result, "<<<DIFF>>>")
  expect_match(result, "<<<END DIFF>>>")
  expect_match(result, "- hello world")
  expect_match(result, "\\+ hi there")
})

test_that("tool_result_to_content extracts image blocks", {
  # Build a fake result with an image marker
  fake_png_b64 <- "iVBORw0KGgo="  # tiny placeholder
  result <- paste0(
    "Captured the plot.\n",
    "<<<SPARX_IMAGE png>>>\n",
    fake_png_b64, "\n",
    "<<<END SPARX_IMAGE>>>\n",
    "Let me analyze it."
  )
  blocks <- tool_result_to_content(result)
  expect_type(blocks, "list")
  # Should have text, image, text
  types <- vapply(blocks, function(b) b$type, character(1))
  expect_true("image" %in% types)
  expect_true("text" %in% types)

  # Find the image block
  img_block <- blocks[types == "image"][[1]]
  expect_equal(img_block$source$media_type, "image/png")
  expect_equal(img_block$source$data, fake_png_b64)
})

test_that("tool_result_to_content passes through plain text", {
  result <- "Just a regular tool result with no markers."
  out <- tool_result_to_content(result)
  expect_type(out, "character")
  expect_equal(out, result)
})

test_that("tool_definitions includes all new tools", {
  tools <- tool_definitions()
  names <- vapply(tools, function(t) t$name, character(1))
  for (expected in c("inspect_plot", "install_packages", "todo_write",
                     "list_files", "read_file", "grep_files",
                     "write_file", "edit_file")) {
    expect_true(expected %in% names, info = paste("missing:", expected))
  }
})
