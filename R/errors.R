#' User-friendly error message translation
#'
#' sparx errors often originate from HTTP responses or R functions that
#' produce terse technical messages. This module translates them into
#' actionable next steps the user can take right now.

#' Translate an error into a user-friendly message
#'
#' Looks at the error message, status codes, and common patterns to
#' produce a message with an actionable suggestion. Always preserves
#' the original message as a sub-bullet so power users can see what
#' actually happened.
#'
#' @param e Error condition, or a character message
#' @param provider Provider that triggered the error (optional, helps tailor suggestions)
#' @return Character scalar — a markdown-flavored error message suitable
#'   for showing in the chat
#' @keywords internal
humanize_error <- function(e, provider = NULL) {
  msg <- if (inherits(e, "condition")) conditionMessage(e) else as.character(e)

  # HTTP 401 — auth
  if (grepl("401|unauthori[sz]ed|invalid.*api.key|authentication.*failed",
            msg, ignore.case = TRUE)) {
    return(paste0(
      "**Your API key was rejected.**\n\n",
      "Your key is invalid, revoked, or for the wrong provider. Fix:\n\n",
      "```r\n",
      "sparx::set_api_key()", if (!is.null(provider)) paste0('  # for ', provider) else '', "\n",
      "```\n\n",
      "Get a fresh key at https://console.anthropic.com (Anthropic) or ",
      "https://platform.openai.com/api-keys (OpenAI).\n\n",
      "<sub>_", msg, "_</sub>"
    ))
  }

  # HTTP 429 — rate limit
  if (grepl("429|rate.*limit|too.many.requests", msg, ignore.case = TRUE)) {
    return(paste0(
      "**You've hit a rate limit.**\n\n",
      "This happens on new accounts with low per-minute token caps. Fix:\n\n",
      "```r\n",
      "# Switch to the cheaper, higher-limit model:\n",
      "options(sparx.model = \"claude-haiku-4-5-20251001\")\n",
      "# Or wait ~60s and retry with the Send button\n",
      "```\n\n",
      "<sub>_", msg, "_</sub>"
    ))
  }

  # HTTP 529 — overloaded
  if (grepl("529|overloaded", msg, ignore.case = TRUE)) {
    return(paste0(
      "**The model provider is overloaded.** Try again in 30 seconds. ",
      "If it keeps happening, switch providers from the dropdown.\n\n",
      "<sub>_", msg, "_</sub>"
    ))
  }

  # HTTP 400 — bad request (likely a tool/schema issue)
  if (grepl("400|bad.request|invalid_request", msg, ignore.case = TRUE)) {
    return(paste0(
      "**The request was malformed.** This is probably a sparx bug. ",
      "Please open an issue at https://github.com/mihirvasudev/sparx/issues ",
      "with the message below.\n\n",
      "<sub>_", msg, "_</sub>"
    ))
  }

  # Keyring problems
  if (grepl("keyring|keychain|credential", msg, ignore.case = TRUE)) {
    return(paste0(
      "**Could not access your system keychain.** Use an env var instead:\n\n",
      "```r\n",
      "Sys.setenv(ANTHROPIC_API_KEY = \"sk-ant-...\")\n",
      "Sys.setenv(OPENAI_API_KEY = \"sk-...\")\n",
      "```\n\n",
      "Add these to your `~/.Renviron` to persist across sessions.\n\n",
      "<sub>_", msg, "_</sub>"
    ))
  }

  # Network / SSL / DNS
  if (grepl("SSL|TLS|connect|network|DNS|resolve|timed?.?out|cannot open|Couldn't connect",
            msg, ignore.case = TRUE)) {
    return(paste0(
      "**Network issue reaching the provider.** Check your internet, or ",
      "if you're on a corporate/hospital network with a proxy, you may ",
      "need to configure it:\n\n",
      "```r\n",
      "Sys.setenv(https_proxy = \"http://your-proxy:8080\")\n",
      "```\n\n",
      "<sub>_", msg, "_</sub>"
    ))
  }

  # No API key configured
  if (grepl("no.*(API|anthropic|openai).*key|not.*configured", msg, ignore.case = TRUE)) {
    p <- provider %||% "anthropic"
    return(paste0(
      "**No API key for ", p, " yet.** Set one:\n\n",
      "```r\n",
      "sparx::set_api_key()", if (p != "anthropic") paste0('  # or provider = "', p, '"') else '', "\n",
      "```\n\n",
      "<sub>_", msg, "_</sub>"
    ))
  }

  # Fallback — unknown error
  paste0(
    "**sparx hit an error.**\n\n",
    "If this keeps happening, open an issue at ",
    "https://github.com/mihirvasudev/sparx/issues with the message below.\n\n",
    "<sub>_", msg, "_</sub>"
  )
}

#' Humanize provider-startup errors (no key, etc.) before an agent call
#'
#' These are about *why we can't even try* rather than why an in-flight
#' request failed.
#'
#' @keywords internal
humanize_startup_error <- function(e) {
  humanize_error(e)
}
