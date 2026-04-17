#' sparx configuration
#'
#' Multi-provider key storage + model defaults. Each provider (anthropic,
#' openai) has its own keyring entry so users can configure one or both.
#'
#' The current provider is a session-level option (`sparx.provider`) and
#' defaults to anthropic. Model defaults are provider-specific.

SPARX_KEYRING_SERVICE <- "sparx"

#' Supported providers + their defaults
#' @keywords internal
PROVIDERS <- list(
  anthropic = list(
    name = "Anthropic (Claude)",
    keyring_user = "anthropic_api_key",
    default_model = "claude-sonnet-4-5-20250929",
    key_prefix = "sk-ant-",
    env_var = "ANTHROPIC_API_KEY"
  ),
  openai = list(
    name = "OpenAI (GPT)",
    keyring_user = "openai_api_key",
    default_model = "gpt-4o",
    key_prefix = "sk-",  # sk- or sk-proj-
    env_var = "OPENAI_API_KEY"
  )
)

#' Get the currently-active provider name
#' @keywords internal
get_provider <- function() {
  getOption("sparx.provider", "anthropic")
}

#' Get provider metadata for the current (or specified) provider
#' @keywords internal
provider_info <- function(provider = NULL) {
  if (is.null(provider)) provider <- get_provider()
  if (!provider %in% names(PROVIDERS)) {
    stop("Unknown provider: ", provider,
         ". Supported: ", paste(names(PROVIDERS), collapse = ", "))
  }
  PROVIDERS[[provider]]
}

#' Set the API key for a provider (or prompt interactively)
#'
#' @param api_key Optional. If NULL (default), prompts interactively.
#' @param provider Provider to set the key for. Defaults to the current
#'   provider (sparx.provider option). Supply "anthropic" or "openai" to
#'   configure that provider specifically.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Interactive prompt for current provider:
#' set_api_key()
#'
#' # Explicitly for OpenAI:
#' set_api_key(provider = "openai")
#'
#' # Programmatic (not recommended for production — key ends up in history):
#' set_api_key("sk-ant-...", provider = "anthropic")
#' }
set_api_key <- function(api_key = NULL, provider = NULL) {
  if (is.null(provider)) provider <- get_provider()
  info <- provider_info(provider)

  if (is.null(api_key)) {
    if (interactive()) {
      api_key <- rstudioapi::askForPassword(
        paste0("Enter your ", info$name, " API key")
      )
    } else {
      stop("Provide api_key argument or run interactively")
    }
  }

  # Soft validation — warn but don't block (prefixes evolve)
  if (!startsWith(api_key, info$key_prefix)) {
    warning(info$name, " API keys usually start with '", info$key_prefix,
            "'. Saving anyway in case you know what you're doing.")
  }

  keyring::key_set_with_value(
    service = SPARX_KEYRING_SERVICE,
    username = info$keyring_user,
    password = api_key
  )

  message(info$name, " API key saved to system keyring.")
  invisible(TRUE)
}

#' Get the stored API key for a provider
#'
#' @param provider Provider (default: current)
#' @return API key string, or NULL if not set
#' @keywords internal
get_api_key <- function(provider = NULL) {
  if (is.null(provider)) provider <- get_provider()
  info <- provider_info(provider)

  tryCatch({
    keyring::key_get(SPARX_KEYRING_SERVICE, info$keyring_user)
  }, error = function(e) {
    # Fallback: env var
    key <- Sys.getenv(info$env_var, unset = "")
    if (nchar(key) > 0) key else NULL
  })
}

#' Get the currently-configured model name
#'
#' Defaults to the provider's preferred model, overridable via
#' `options(sparx.model = "...")` or `options(sparx.anthropic_model = ...)`
#' / `options(sparx.openai_model = ...)` for per-provider overrides.
#' @keywords internal
get_model <- function(provider = NULL) {
  if (is.null(provider)) provider <- get_provider()
  info <- provider_info(provider)

  # Check per-provider option first
  per_provider_key <- paste0("sparx.", provider, "_model")
  per_provider <- getOption(per_provider_key, NULL)
  if (!is.null(per_provider)) return(per_provider)

  # Then the generic override (intended for the current provider)
  generic <- getOption("sparx.model", NULL)
  if (!is.null(generic)) return(generic)

  info$default_model
}

#' Switch the active provider
#'
#' @param provider "anthropic" or "openai"
#' @export
set_provider <- function(provider) {
  provider_info(provider)  # Validates
  options(sparx.provider = provider)
  message("sparx: active provider is now ", provider)
  invisible(provider)
}

#' Which providers have an API key configured?
#' @keywords internal
configured_providers <- function() {
  Filter(function(p) {
    key <- tryCatch(get_api_key(p), error = function(e) NULL)
    !is.null(key) && nzchar(key)
  }, names(PROVIDERS))
}
