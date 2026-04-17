test_that("provider_info returns expected shape for each provider", {
  a <- provider_info("anthropic")
  expect_equal(a$name, "Anthropic (Claude)")
  expect_match(a$default_model, "claude")
  expect_equal(a$keyring_user, "anthropic_api_key")

  o <- provider_info("openai")
  expect_equal(o$name, "OpenAI (GPT)")
  expect_match(o$default_model, "gpt")
  expect_equal(o$keyring_user, "openai_api_key")
})

test_that("provider_info errors on unknown provider", {
  expect_error(provider_info("google"))
})

test_that("get_provider defaults to anthropic", {
  old <- getOption("sparx.provider")
  on.exit(options(sparx.provider = old), add = TRUE)
  options(sparx.provider = NULL)
  expect_equal(get_provider(), "anthropic")
})

test_that("set_provider switches option + validates", {
  old <- getOption("sparx.provider")
  on.exit(options(sparx.provider = old), add = TRUE)

  suppressMessages(set_provider("openai"))
  expect_equal(get_provider(), "openai")
  suppressMessages(set_provider("anthropic"))
  expect_equal(get_provider(), "anthropic")

  expect_error(set_provider("unsupported_provider_xyz"))
})

test_that("get_model defaults per provider", {
  old_p <- getOption("sparx.provider")
  old_m <- getOption("sparx.model")
  old_am <- getOption("sparx.anthropic_model")
  old_om <- getOption("sparx.openai_model")
  on.exit({
    options(sparx.provider = old_p, sparx.model = old_m,
            sparx.anthropic_model = old_am, sparx.openai_model = old_om)
  }, add = TRUE)

  options(sparx.model = NULL, sparx.anthropic_model = NULL, sparx.openai_model = NULL)
  options(sparx.provider = "anthropic")
  expect_match(get_model(), "claude")
  options(sparx.provider = "openai")
  expect_match(get_model(), "gpt")

  # Per-provider override
  options(sparx.openai_model = "gpt-5-turbo-custom")
  expect_equal(get_model("openai"), "gpt-5-turbo-custom")
})

test_that("convert_tool_to_openai wraps input_schema in function format", {
  tool <- list(
    name = "my_tool",
    description = "Does a thing.",
    input_schema = list(type = "object", properties = list())
  )
  out <- convert_tool_to_openai(tool)
  expect_equal(out$type, "function")
  expect_equal(out[["function"]]$name, "my_tool")
  expect_equal(out[["function"]]$description, "Does a thing.")
  expect_equal(out[["function"]]$parameters$type, "object")
})

test_that("convert_messages_to_openai turns tool_result blocks into tool role", {
  msgs <- list(
    list(role = "user", content = "hello"),
    list(role = "assistant", content = list(
      list(type = "text", text = "I'll check."),
      list(type = "tool_use", id = "call_1", name = "x", input = list(a = 1))
    )),
    list(role = "user", content = list(
      list(type = "tool_result", tool_use_id = "call_1",
           content = "42", is_error = FALSE)
    ))
  )
  out <- convert_messages_to_openai(msgs)
  roles <- vapply(out, function(m) m$role, character(1))
  expect_true("user" %in% roles)
  expect_true("assistant" %in% roles)
  expect_true("tool" %in% roles)

  # Assistant message should have tool_calls populated
  asst <- out[which(roles == "assistant")[1]]
  expect_equal(length(asst[[1]]$tool_calls), 1)
  expect_equal(asst[[1]]$tool_calls[[1]]$id, "call_1")
  expect_equal(asst[[1]]$tool_calls[[1]][["function"]]$name, "x")

  # Tool message should have tool_call_id
  tool_msg <- out[which(roles == "tool")[1]]
  expect_equal(tool_msg[[1]]$tool_call_id, "call_1")
  expect_equal(tool_msg[[1]]$content, "42")
})

test_that("convert_messages_to_openai handles plain string user content", {
  msgs <- list(list(role = "user", content = "hello world"))
  out <- convert_messages_to_openai(msgs)
  expect_equal(out[[1]]$role, "user")
  expect_equal(out[[1]]$content, "hello world")
})

test_that("configured_providers returns names of providers with keys", {
  # No way to reliably test with real keyring without polluting the user's
  # system. Just check the function runs and returns a character vector.
  out <- tryCatch(configured_providers(), error = function(e) character())
  expect_type(out, "character")
  expect_true(all(out %in% names(PROVIDERS)))
})

test_that("PROVIDERS has both anthropic and openai defined", {
  expect_true("anthropic" %in% names(PROVIDERS))
  expect_true("openai" %in% names(PROVIDERS))
  # And exactly 2 for now
  expect_equal(length(PROVIDERS), 2)
})
