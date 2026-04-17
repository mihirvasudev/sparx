test_that("tool_definitions_filtered('plan') removes write tools", {
  all_tools <- tool_definitions()
  plan_tools <- tool_definitions_filtered("plan")
  all_names <- vapply(all_tools, function(t) t$name, character(1))
  plan_names <- vapply(plan_tools, function(t) t$name, character(1))

  # Write/mutate tools must NOT be in plan mode
  for (forbidden in c("write_file", "edit_file", "run_in_session",
                      "install_packages", "git_commit")) {
    expect_true(forbidden %in% all_names, info = forbidden)
    expect_false(forbidden %in% plan_names, info = forbidden)
  }

  # Read-only tools MUST still be there
  for (kept in c("inspect_data", "read_file", "grep_files",
                 "run_r_preview", "check_package", "git_status")) {
    expect_true(kept %in% plan_names, info = kept)
  }
})

test_that("tool_definitions_filtered('normal') returns everything", {
  all_tools <- tool_definitions()
  normal_tools <- tool_definitions_filtered("normal")
  expect_equal(length(all_tools), length(normal_tools))
})

test_that("build_system_prompt appends PLAN_MODE_ADDENDUM when plan_mode is on", {
  old <- getOption("sparx.plan_mode")
  on.exit(options(sparx.plan_mode = old), add = TRUE)

  ctx <- list(
    r_version = "4.4.2",
    packages = character(),
    dataframes = list(),
    script = list(path = "<none>", contents = ""),
    cursor = list(line = 1, column = 1),
    selection = ""
  )

  options(sparx.plan_mode = FALSE)
  p_off <- build_system_prompt(ctx)
  expect_false(grepl("PLAN MODE IS ON", p_off))

  options(sparx.plan_mode = TRUE)
  p_on <- build_system_prompt(ctx)
  expect_true(grepl("PLAN MODE IS ON", p_on))
  expect_true(grepl("numbered plan", p_on))
})

test_that("should_compact respects sparx.compact_threshold option", {
  old <- getOption("sparx.compact_threshold")
  on.exit(options(sparx.compact_threshold = old), add = TRUE)

  .sparx_runtime_state$last_input_tokens <- 50000L
  options(sparx.compact_threshold = 100000L)
  expect_false(should_compact())

  .sparx_runtime_state$last_input_tokens <- 120000L
  expect_true(should_compact())

  options(sparx.compact_threshold = 10000L)
  .sparx_runtime_state$last_input_tokens <- 50000L
  expect_true(should_compact())
})

test_that("compact_conversation preserves recent user turns", {
  # Build a fake messages list: 5 user-turn pairs
  msgs <- list()
  for (i in 1:5) {
    msgs <- c(msgs, list(
      list(role = "user", content = paste0("user msg ", i)),
      list(role = "assistant", content = list(
        list(type = "text", text = paste0("assistant reply ", i))
      ))
    ))
  }

  # Stub call_provider_streaming so we don't make a real API call
  old_call <- get("call_provider_streaming", envir = globalenv())
  assign("call_provider_streaming", function(...) {
    list(
      content = list(list(type = "text", text = "## Summary\n\nFake summary of old turns.")),
      stop_reason = "end_turn",
      usage = list(input_tokens = 100L, output_tokens = 20L)
    )
  }, envir = globalenv())
  on.exit(assign("call_provider_streaming", old_call, envir = globalenv()),
          add = TRUE)

  out <- compact_conversation(msgs, keep_recent = 2)

  # Expect: summary pair (user + assistant) + last 2 user+asst pairs = 6 messages
  # (2 kept user turns + their paired assistants, +2 summary turns)
  expect_length(out, 6)
  expect_equal(out[[1]]$role, "user")
  expect_match(out[[1]]$content, "Earlier conversation")
  expect_equal(out[[2]]$role, "assistant")

  # The last 4 should be the original last 2 user-asst pairs
  expect_equal(out[[3]]$content, "user msg 4")
  expect_equal(out[[5]]$content, "user msg 5")
})

test_that("compact_conversation no-ops on very short message lists", {
  msgs <- list(list(role = "user", content = "hello"))
  out <- compact_conversation(msgs)
  expect_identical(out, msgs)
})

test_that("format_messages_for_summary produces readable text", {
  msgs <- list(
    list(role = "user", content = "analyze this"),
    list(role = "assistant", content = list(
      list(type = "text", text = "sure"),
      list(type = "tool_use", id = "t1", name = "inspect_data",
           input = list(name = "df"))
    )),
    list(role = "user", content = list(
      list(type = "tool_result", tool_use_id = "t1",
           content = "df has 100 rows", is_error = FALSE)
    ))
  )
  out <- format_messages_for_summary(msgs)
  expect_match(out, "USER: analyze this")
  expect_match(out, "ASSISTANT: sure")
  expect_match(out, "TOOL_CALL .inspect_data")
  expect_match(out, "TOOL_RESULT")
})
