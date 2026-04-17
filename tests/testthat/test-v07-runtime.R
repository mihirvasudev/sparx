test_that("sparx_request_abort / sparx_clear_abort toggle flag", {
  sparx_clear_abort()
  expect_false(sparx_abort_requested())
  sparx_request_abort()
  expect_true(sparx_abort_requested())
  sparx_clear_abort()
  expect_false(sparx_abort_requested())
})

test_that("sparx_reset_tokens zeros the counters", {
  .sparx_runtime_state$input_tokens <- 1000L
  .sparx_runtime_state$output_tokens <- 500L
  sparx_reset_tokens()
  expect_equal(.sparx_runtime_state$input_tokens, 0)
  expect_equal(.sparx_runtime_state$output_tokens, 0)
})

test_that("toggle_label formats correctly", {
  expect_equal(toggle_label("Live", TRUE), "Live: ON")
  expect_equal(toggle_label("Live", FALSE), "Live: off")
})

test_that("git_commit is refused without allow_git option", {
  old <- getOption("sparx.allow_git")
  on.exit(options(sparx.allow_git = old), add = TRUE)
  options(sparx.allow_git = FALSE)

  result <- tool_git_commit("test commit")
  expect_match(result, "refused|sparx.allow_git")
})

test_that("git_commit rejects empty messages", {
  old <- getOption("sparx.allow_git")
  on.exit(options(sparx.allow_git = old), add = TRUE)
  options(sparx.allow_git = TRUE)

  expect_match(tool_git_commit(""), "required")
  expect_match(tool_git_commit(NULL), "required")
})

test_that("tool_definitions includes git_commit", {
  tools <- tool_definitions()
  names <- vapply(tools, function(t) t$name, character(1))
  expect_true("git_commit" %in% names)
  expect_gte(length(tools), 19)  # 18 previous + git_commit
})
