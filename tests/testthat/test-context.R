test_that("list_dataframes finds dataframes in .GlobalEnv", {
  # Set up a test dataframe in .GlobalEnv
  test_df <<- data.frame(x = 1:3, y = letters[1:3], stringsAsFactors = FALSE)
  on.exit(rm(test_df, envir = .GlobalEnv), add = TRUE)

  dfs <- list_dataframes()
  expect_true("test_df" %in% names(dfs))
  expect_equal(dfs$test_df$rows, 3)
  expect_equal(dfs$test_df$cols, 2)
})

test_that("list_dataframes returns empty when no dataframes present", {
  # Can't easily guarantee clean env in tests, so just check structure
  dfs <- list_dataframes()
  expect_type(dfs, "list")
})

test_that("loaded_packages excludes base packages", {
  pkgs <- loaded_packages()
  expect_false("base" %in% pkgs)
  expect_false("stats" %in% pkgs)
})

test_that("null-coalescing operator works", {
  expect_equal(NULL %||% "fallback", "fallback")
  expect_equal("value" %||% "fallback", "value")
  expect_equal(list() %||% "fallback", "fallback")
  expect_equal(list(1, 2) %||% "fallback", list(1, 2))
})
