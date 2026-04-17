#' Design tokens — single source of style truth for sparx
#'
#' Every CSS rule in ui.R references these via glue::glue substitution.
#' To reskin sparx: edit this file only.

#' @keywords internal
SPARX_TOKENS <- list(
  # ── Spacing (4px scale) ──────────────────────────────
  spacing = list(
    xs  = "4px",
    sm  = "8px",
    md  = "12px",
    lg  = "16px",
    xl  = "20px",
    xxl = "32px"
  ),

  # ── Colors (light mode) ──────────────────────────────
  light = list(
    bg_chat       = "#fafafa",
    bg_surface    = "#ffffff",
    bg_muted      = "#f9fafb",
    bg_input      = "#ffffff",
    bg_code       = "#0f172a",
    bg_code_text  = "#e2e8f0",

    border        = "#e5e7eb",
    border_subtle = "#f3f4f6",
    border_strong = "#d1d5db",

    text          = "#111827",
    text_muted    = "#6b7280",
    text_subtle   = "#9ca3af",

    accent        = "#2563eb",
    accent_hover  = "#1d4ed8",
    accent_bg     = "#eef2ff",
    accent_border = "#c7d2fe",

    success       = "#10b981",
    success_bg    = "#d1fae5",
    success_text  = "#065f46",

    warning       = "#f59e0b",
    warning_bg    = "#fef3c7",

    danger        = "#ef4444",
    danger_bg     = "#fee2e2",
    danger_text   = "#991b1b",

    tool          = "#8b5cf6",
    tool_bg       = "#faf5ff",
    tool_border   = "#e9d5ff",

    user_bg       = "#2563eb",
    user_text     = "#ffffff"
  ),

  # ── Colors (dark mode) ───────────────────────────────
  dark = list(
    bg_chat       = "#1a1a1a",
    bg_surface    = "#262626",
    bg_muted      = "#2d2d2d",
    bg_input      = "#2d2d2d",
    bg_code       = "#0a0a0a",
    bg_code_text  = "#d4d4d4",

    border        = "#404040",
    border_subtle = "#333333",
    border_strong = "#525252",

    text          = "#f3f4f6",
    text_muted    = "#9ca3af",
    text_subtle   = "#6b7280",

    accent        = "#60a5fa",
    accent_hover  = "#93c5fd",
    accent_bg     = "#1e3a8a33",
    accent_border = "#3b82f6",

    success       = "#34d399",
    success_bg    = "#06402733",
    success_text  = "#6ee7b7",

    warning       = "#fbbf24",
    warning_bg    = "#78350f33",

    danger        = "#f87171",
    danger_bg     = "#7f1d1d33",
    danger_text   = "#fca5a5",

    tool          = "#a78bfa",
    tool_bg       = "#4c1d9533",
    tool_border   = "#6d28d9",

    user_bg       = "#3b82f6",
    user_text     = "#ffffff"
  ),

  # ── Typography ───────────────────────────────────────
  font = list(
    sans = "-apple-system, BlinkMacSystemFont, 'Inter', 'Segoe UI', Helvetica, Arial, sans-serif",
    mono = "'SF Mono', Menlo, Monaco, 'Cascadia Code', 'Fira Code', Consolas, monospace",

    size_xs   = "10px",
    size_sm   = "11px",
    size_base = "13px",
    size_md   = "14px",
    size_lg   = "16px",
    size_xl   = "18px",

    weight_normal = "400",
    weight_medium = "500",
    weight_bold   = "600",

    line_tight   = "1.4",
    line_normal  = "1.55",
    line_relaxed = "1.7"
  ),

  # ── Motion ───────────────────────────────────────────
  motion = list(
    fast   = "120ms cubic-bezier(0.4, 0, 0.2, 1)",
    normal = "200ms cubic-bezier(0.4, 0, 0.2, 1)",
    slow   = "300ms cubic-bezier(0.4, 0, 0.2, 1)"
  ),

  # ── Radius ───────────────────────────────────────────
  radius = list(
    sm = "4px",
    md = "6px",
    lg = "10px",
    xl = "12px",
    pill = "9999px"
  ),

  # ── Shadows ──────────────────────────────────────────
  shadow = list(
    sm = "0 1px 2px rgba(0, 0, 0, 0.04)",
    md = "0 2px 4px rgba(0, 0, 0, 0.06)",
    lg = "0 8px 16px rgba(0, 0, 0, 0.08)"
  )
)

#' Detect whether RStudio is in dark mode
#'
#' @return Boolean; FALSE if rstudioapi is unavailable or returns nothing.
#' @keywords internal
sparx_is_dark_theme <- function() {
  theme <- tryCatch(
    rstudioapi::getThemeInfo(),
    error = function(e) NULL
  )
  if (is.null(theme)) return(FALSE)
  isTRUE(theme$dark)
}

#' Flatten a nested token list to a single `key_subkey` lookup
#'
#' @keywords internal
flatten_tokens <- function(x, prefix = "") {
  out <- list()
  for (k in names(x)) {
    val <- x[[k]]
    key <- if (nchar(prefix) > 0) paste0(prefix, "_", k) else k
    if (is.list(val)) {
      out <- c(out, flatten_tokens(val, key))
    } else {
      out[[key]] <- val
    }
  }
  out
}

#' Build the token map for the current theme
#'
#' Merges base tokens with the appropriate color palette (light or dark).
#'
#' @keywords internal
build_token_map <- function(dark = FALSE) {
  palette <- if (dark) SPARX_TOKENS$dark else SPARX_TOKENS$light
  merged <- list(
    color  = palette,
    font   = SPARX_TOKENS$font,
    space  = SPARX_TOKENS$spacing,
    motion = SPARX_TOKENS$motion,
    radius = SPARX_TOKENS$radius,
    shadow = SPARX_TOKENS$shadow
  )
  flatten_tokens(merged)
}

#' Generate CSS variable declarations from tokens
#'
#' Emits `--sparx-color-accent: #2563eb;` etc. inside a :root block.
#' Dark-mode overrides go inside `[data-theme="dark"]`.
#'
#' @keywords internal
tokens_to_css_variables <- function() {
  light <- flatten_tokens(list(color = SPARX_TOKENS$light))
  dark  <- flatten_tokens(list(color = SPARX_TOKENS$dark))

  light_lines <- paste0(
    "  --sparx-", gsub("_", "-", names(light)), ": ", unlist(light), ";"
  )
  dark_lines <- paste0(
    "  --sparx-", gsub("_", "-", names(dark)), ": ", unlist(dark), ";"
  )

  paste(
    ":root {",
    paste(light_lines, collapse = "\n"),
    "}",
    "[data-theme=\"dark\"] {",
    paste(dark_lines, collapse = "\n"),
    "}",
    sep = "\n"
  )
}
