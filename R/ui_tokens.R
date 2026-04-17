#' Design tokens — single source of truth for sparx visual style
#'
#' Emitted as CSS custom properties (variables) on `:root` (light palette)
#' and `[data-theme="dark"]` (dark palette) so theming is a class swap,
#' not a CSS regeneration.
#'
#' Design philosophy: warm neutrals (stone-* family) not cool grays,
#' generous typography hierarchy (11-28px), clear motion curves,
#' semantic color meaning per-token (success vs warning vs tool).

SPARX_TOKENS <- list(
  # ── Colors: light palette ──────────────────────────────────────────────
  light = list(
    # Backgrounds
    bg_chat          = "#fbfbfa",   # warm off-white (stone-50 tint)
    bg_surface       = "#ffffff",
    bg_muted         = "#f5f5f4",   # stone-100
    bg_subtle        = "#fafaf9",   # between chat + muted
    bg_input         = "#ffffff",
    bg_code          = "#0c0a09",   # warm charcoal (stone-950)
    bg_code_text     = "#e7e5e4",   # stone-200, soft on dark

    # Borders
    border           = "#e7e5e4",   # stone-200
    border_subtle    = "#f5f5f4",   # stone-100
    border_strong    = "#d6d3d1",   # stone-300

    # Text
    text             = "#0c0a09",   # stone-950
    text_muted       = "#57534e",   # stone-600
    text_subtle      = "#a8a29e",   # stone-400

    # Accent (blue)
    accent           = "#3b82f6",   # blue-500
    accent_hover     = "#2563eb",   # blue-600
    accent_bg        = "#eff6ff",   # blue-50
    accent_border    = "#bfdbfe",   # blue-200

    # Semantic
    success          = "#10b981",   # emerald-500
    success_bg       = "#d1fae5",   # emerald-100
    success_text     = "#065f46",   # emerald-800

    warning          = "#f59e0b",   # amber-500
    warning_bg       = "#fef3c7",   # amber-100
    warning_text     = "#78350f",   # amber-900

    danger           = "#ef4444",   # red-500
    danger_bg        = "#fee2e2",   # red-100
    danger_text      = "#991b1b",   # red-900

    # Tool categories (colored icons for tool rows)
    tool             = "#8b5cf6",   # violet-500 (generic write)
    tool_bg          = "#faf5ff",
    tool_border      = "#e9d5ff",
    tool_read        = "#3b82f6",   # blue  — inspect / read / grep
    tool_write       = "#8b5cf6",   # violet — write / edit / install
    tool_run         = "#10b981",   # emerald — run / exec
    tool_git         = "#059669",   # green — git status / diff / commit
    tool_web         = "#f59e0b",   # amber — fetch_url

    # User message pill
    user_bg          = "#3b82f6",   # blue-500
    user_text        = "#ffffff",

    # Overlays
    scrim            = "rgba(0, 0, 0, 0.04)"
  ),

  # ── Colors: dark palette ───────────────────────────────────────────────
  dark = list(
    bg_chat          = "#0c0a09",   # warm black
    bg_surface       = "#1c1917",   # stone-900
    bg_muted         = "#292524",   # stone-800
    bg_subtle        = "#1c1917",
    bg_input         = "#1c1917",
    bg_code          = "#09090b",   # near-pure black
    bg_code_text     = "#d4d4d8",   # zinc-300

    border           = "#292524",
    border_subtle    = "#1c1917",
    border_strong    = "#44403c",   # stone-700

    text             = "#fafaf9",   # stone-50
    text_muted       = "#a8a29e",   # stone-400
    text_subtle      = "#78716c",   # stone-500

    accent           = "#60a5fa",   # blue-400
    accent_hover     = "#93c5fd",   # blue-300
    accent_bg        = "rgba(59, 130, 246, 0.12)",
    accent_border    = "#3b82f6",

    success          = "#34d399",
    success_bg       = "rgba(16, 185, 129, 0.15)",
    success_text     = "#6ee7b7",

    warning          = "#fbbf24",
    warning_bg       = "rgba(245, 158, 11, 0.15)",
    warning_text     = "#fcd34d",

    danger           = "#f87171",
    danger_bg        = "rgba(239, 68, 68, 0.15)",
    danger_text      = "#fca5a5",

    tool             = "#a78bfa",
    tool_bg          = "rgba(139, 92, 246, 0.1)",
    tool_border      = "rgba(139, 92, 246, 0.3)",
    tool_read        = "#60a5fa",
    tool_write       = "#a78bfa",
    tool_run         = "#34d399",
    tool_git         = "#34d399",
    tool_web         = "#fbbf24",

    user_bg          = "#3b82f6",
    user_text        = "#ffffff",

    scrim            = "rgba(255, 255, 255, 0.04)"
  ),

  # ── Typography ──────────────────────────────────────────────────────────
  font = list(
    sans       = "Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Helvetica Neue', Arial, sans-serif",
    mono       = "'JetBrains Mono', 'SF Mono', Menlo, Monaco, 'Cascadia Code', 'Fira Code', Consolas, monospace",

    size_xs    = "11px",
    size_sm    = "12px",
    size_base  = "14px",   # body text
    size_md    = "15px",
    size_lg    = "17px",
    size_xl    = "20px",   # welcome heading
    size_xxl   = "28px",   # logo mark

    weight_normal  = "400",
    weight_medium  = "500",
    weight_semibold = "600",
    weight_bold    = "700",

    line_tight   = "1.3",
    line_snug    = "1.4",
    line_normal  = "1.55",
    line_relaxed = "1.65",

    letter_tight = "-0.01em",
    letter_wide  = "0.04em"
  ),

  # ── Motion ──────────────────────────────────────────────────────────────
  motion = list(
    fast    = "120ms cubic-bezier(0.4, 0, 0.2, 1)",
    normal  = "200ms cubic-bezier(0.4, 0, 0.2, 1)",
    slow    = "320ms cubic-bezier(0.4, 0, 0.2, 1)",
    bounce  = "400ms cubic-bezier(0.34, 1.56, 0.64, 1)"
  ),

  # ── Radius ──────────────────────────────────────────────────────────────
  radius = list(
    xs   = "3px",
    sm   = "5px",
    md   = "7px",
    lg   = "9px",
    xl   = "12px",
    pill = "9999px"
  ),

  # ── Shadows (light mode; dark overrides via CSS vars) ──────────────────
  shadow = list(
    xs = "0 1px 2px 0 rgba(0, 0, 0, 0.03)",
    sm = "0 1px 3px 0 rgba(0, 0, 0, 0.04), 0 1px 2px -1px rgba(0, 0, 0, 0.04)",
    md = "0 4px 6px -1px rgba(0, 0, 0, 0.05), 0 2px 4px -2px rgba(0, 0, 0, 0.03)",
    lg = "0 10px 15px -3px rgba(0, 0, 0, 0.07), 0 4px 6px -4px rgba(0, 0, 0, 0.05)",
    focus = "0 0 0 3px rgba(59, 130, 246, 0.18)"   # soft accent glow
  ),

  # ── Spacing scale (4px) ────────────────────────────────────────────────
  spacing = list(
    `0_5` = "2px",
    `1`   = "4px",
    `1_5` = "6px",
    `2`   = "8px",
    `2_5` = "10px",
    `3`   = "12px",
    `4`   = "16px",
    `5`   = "20px",
    `6`   = "24px",
    `8`   = "32px"
  )
)

#' Detect whether RStudio is in dark mode
#' @return Boolean; FALSE if rstudioapi unavailable
#' @keywords internal
sparx_is_dark_theme <- function() {
  theme <- tryCatch(rstudioapi::getThemeInfo(), error = function(e) NULL)
  if (is.null(theme)) return(FALSE)
  isTRUE(theme$dark)
}

#' Flatten a nested token list
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

#' Build a token lookup map for the current theme (tests call this)
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

#' Generate CSS variable declarations
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
