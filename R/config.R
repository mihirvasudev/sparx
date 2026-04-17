#' sparx configuration
#'
#' Functions for managing the API key and model settings.

SPARX_KEYRING_SERVICE <- "sparx"
SPARX_API_KEY_USER <- "anthropic_api_key"
SPARX_DEFAULT_MODEL <- "claude-sonnet-4-5-20250929"

#' Set the Anthropic API key
#'
#' Stores your Anthropic API key in the system keyring for sparx to use.
#' Your key is encrypted at rest and never leaves your machine.
#'
#' @param api_key Optional. If NULL (default), you'll be prompted interactively.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' set_api_key()  # Prompts for key
#' set_api_key("sk-ant-...")
#' }
set_api_key <- function(api_key = NULL) {
  if (is.null(api_key)) {
    if (interactive()) {
      api_key <- rstudioapi::askForPassword("Enter your Anthropic API key")
    } else {
      stop("Provide api_key argument or run interactively")
    }
  }

  if (!grepl("^sk-ant-", api_key)) {
    stop("Anthropic API keys start with 'sk-ant-'. Check your key.")
  }

  keyring::key_set_with_value(
    service = SPARX_KEYRING_SERVICE,
    username = SPARX_API_KEY_USER,
    password = api_key
  )

  message("API key saved to system keyring.")
  invisible(TRUE)
}

#' Get the stored Anthropic API key
#'
#' @return API key string, or NULL if not set
#' @keywords internal
get_api_key <- function() {
  tryCatch({
    keyring::key_get(SPARX_KEYRING_SERVICE, SPARX_API_KEY_USER)
  }, error = function(e) {
    # Fallback: env var
    key <- Sys.getenv("ANTHROPIC_API_KEY", unset = "")
    if (nchar(key) > 0) key else NULL
  })
}

#' Get the configured model
#' @keywords internal
get_model <- function() {
  getOption("sparx.model", SPARX_DEFAULT_MODEL)
}
