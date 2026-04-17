test_that("tool_definitions returns a list with required fields", {
  tools <- tool_definitions()
  expect_true(length(tools) >= 4)

  for (t in tools) {
    expect_true("name" %in% names(t))
    expect_true("description" %in% names(t))
    expect_true("input_schema" %in% names(t))
    expect_equal(t$input_schema$type, "object")
  }
})

test_that("inspect_data returns structure for a real dataframe", {
  test_df <<- data.frame(
    x = 1:10,
    y = letters[1:10],
    z = rnorm(10),
    stringsAsFactors = FALSE
  )
  on.exit(rm(test_df, envir = .GlobalEnv), add = TRUE)

  result <- tool_inspect_data("test_df", n_sample = 3)
  expect_type(result, "character")
  expect_match(result, "10 rows x 3 columns")
  expect_match(result, "x <")
  expect_match(result, "y <")
})

test_that("inspect_data errors gracefully for missing objects", {
  result <- tool_inspect_data("nonexistent_object_xyz")
  expect_match(result, "ERROR")
})

test_that("inspect_data errors gracefully for non-dataframes", {
  test_not_df <<- 1:5
  on.exit(rm(test_not_df, envir = .GlobalEnv), add = TRUE)

  result <- tool_inspect_data("test_not_df")
  expect_match(result, "not a dataframe")
})

test_that("check_package works for installed and missing packages", {
  # stats is always installed
  result_installed <- tool_check_package("stats")
  expect_match(result_installed, "is installed")

  # unlikely-to-exist package name
  result_missing <- tool_check_package("zzzz_nonexistent_package_xyz")
  expect_match(result_missing, "NOT installed")
})

test_that("execute_tool dispatches correctly", {
  result <- execute_tool("check_package", list(package = "stats"))
  expect_match(result, "installed")

  result_unknown <- execute_tool("unknown_tool_name", list())
  expect_match(result_unknown, "unknown tool")
})
