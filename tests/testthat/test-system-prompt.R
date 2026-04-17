test_that("build_system_prompt includes key context sections", {
  ctx <- list(
    r_version = "4.4.2",
    packages = c("dplyr", "ggplot2"),
    dataframes = list(
      my_data = list(
        rows = 100,
        cols = 3,
        columns = list(
          list(name = "x", type = "numeric", n_unique = 50, n_missing = 0),
          list(name = "y", type = "character", n_unique = 10, n_missing = 2)
        )
      )
    ),
    script = list(path = "/tmp/test.R", contents = "library(dplyr)\nx <- 1"),
    cursor = list(line = 2, column = 1),
    selection = ""
  )

  prompt <- build_system_prompt(ctx)

  expect_type(prompt, "character")
  expect_true(grepl("sparx", prompt, fixed = TRUE))
  expect_true(grepl("4.4.2", prompt, fixed = TRUE))
  expect_true(grepl("dplyr", prompt, fixed = TRUE))
  expect_true(grepl("my_data", prompt, fixed = TRUE))
  expect_true(grepl("inspect_data", prompt, fixed = TRUE))
})

test_that("summarize_dataframes_for_prompt handles empty dataframes list", {
  result <- summarize_dataframes_for_prompt(list())
  expect_match(result, "No dataframes")
})

test_that("truncate_script trims to max_chars", {
  long <- paste(rep("x", 5000), collapse = "")
  truncated <- truncate_script(long, max_chars = 100)
  expect_true(nchar(truncated) < 200)  # 100 + truncation marker
  expect_match(truncated, "truncated")
})

test_that("truncate_script leaves short scripts alone", {
  short <- "library(dplyr)"
  expect_equal(truncate_script(short), short)
})
