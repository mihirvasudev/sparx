#' sparx: AI pair-programmer for RStudio
#'
#' sparx adds an AI research assistant to RStudio. Describe what you want in
#' English; sparx reads your script, session, and data, then generates R code
#' you can insert or run.
#'
#' @section Getting started:
#' \preformatted{
#' # 1. Install
#' remotes::install_github("mihirvasudev/sparx")
#'
#' # 2. Set a key for your preferred provider
#' sparx::set_api_key()                          # Anthropic (default)
#' sparx::set_api_key(provider = "openai")       # OpenAI (optional)
#'
#' # 3. In RStudio: Addins -> Open sparx Chat
#' # Or bind a keyboard shortcut via Tools -> Modify Keyboard Shortcuts
#' # Switch providers mid-session via the dropdown in the chat panel
#' }
#'
#' @section Main functions:
#' \itemize{
#'   \item \code{\link{open_chat}}: Open the chat gadget
#'   \item \code{\link{explain_selection}}: Explain selected code
#'   \item \code{\link{fix_selection}}: Fix selected code
#'   \item \code{\link{improve_selection}}: Rewrite selected code idiomatically
#'   \item \code{\link{set_api_key}}: Store a provider API key securely
#'   \item \code{\link{set_provider}}: Switch between Anthropic and OpenAI
#' }
#'
#' @keywords internal
"_PACKAGE"
