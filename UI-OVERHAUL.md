# sparx — UI/UX Overhaul Plan

**Author:** sparx team
**Version target:** v0.9.0
**Status:** Draft for approval

> The current UI works. It also feels like a Shiny gadget from 2017. Users (specifically: one real user, you, after 10 minutes of real use) already said "the UI isn't that great honestly." This plan lays out what to rebuild and why.

---

## 1. Goals

1. **Feel like a modern AI chat app**, not a form embedded in a pane. Claude.ai / Cursor / ChatGPT Plus are the comparables.
2. **Survive the 500×400 pane** (RStudio's default Viewer size) while also scaling to 1200px when users pop it out.
3. **Make the agentic loop legible** — when the agent runs 4 tools in a row, the user should understand at a glance what happened and why.
4. **Zero new dependencies unless justified** — every added JS library is a CRAN risk.
5. **Ship in a week of focused work** (not a month). We're still at product-market-fit stage; perfect is the enemy of real.

## 2. Design principles

- **Conversation first**: the chat thread owns ≥ 70% of the pane. Everything else collapses.
- **Progressive disclosure**: tool details are visible when you want them, invisible when you don't.
- **One source of truth for style**: design tokens (spacing / color / type), not one-off CSS.
- **Works with RStudio's theme**: the pane should feel like it belongs, not like a foreign pop-up.
- **Hotkey-friendly**: power users rarely touch the mouse.

## 3. Current state — what's wrong

From the real-use audit after v0.8.2:

| # | Issue | Severity |
|---|---|---|
| 1 | 400px min pane height leaves ~200px for the thread itself | **Critical** |
| 2 | Auto-scroll was fighting the user (fixed in v0.8.2) | High (resolved) |
| 3 | 4+ tool calls stack as a repetitive purple wall | **High** |
| 4 | Textarea fixed at 3 rows, no expand / collapse | High |
| 5 | Welcome text wraps badly in a 500px pane | Medium |
| 6 | Controls bar shows 3 toggles + dropdown + tokens → still wide | Medium |
| 7 | Code-block Insert/Run/Copy buttons wrap on narrow widths | Medium |
| 8 | Tool results silently truncated at 1200 chars — no expand | Medium |
| 9 | No markdown beyond bold / inline code — no lists, headings, tables | Medium |
| 10 | No visual difference between user / assistant / tool except color | Medium |
| 11 | No keyboard shortcuts beyond Cmd+Enter | Low |
| 12 | Token counter updates every 1s, eats visual space | Low |
| 13 | No dark-mode support; RStudio dark theme users see jarring light UI | Low |

## 4. Design direction

### 4.1 Visual vocabulary

Take cues from:

- **Claude.ai** — generous whitespace, subtle shadows, clean typography, no chrome for chrome's sake
- **Cursor** — inline tool cards that feel like native editor actions, diff views embedded in chat
- **Linear** — dense but readable, good use of muted colors, modern hover states
- **Posit Assistant (screenshots)** — integrates natively with RStudio's fonts and theme

### 4.2 Three-zone layout

```
┌─────────────────────────────────────────┐
│  Header (28px, collapsible)              │  ← provider pill, gear menu, tokens
├─────────────────────────────────────────┤
│                                          │
│                                          │
│  Thread (flex: 1, primary zone)          │  ← ≥70% of vertical space
│    - User bubbles                        │
│    - Assistant responses (with markdown) │
│    - Tool cards (collapsible)            │
│    - Code blocks (syntax-highlighted)    │
│                                          │
├─────────────────────────────────────────┤
│  Input (auto-grow, 44px → 200px max)     │
└─────────────────────────────────────────┘
```

### 4.3 Design tokens

Introduce `R/ui_tokens.R` (new file) as the single source of style truth:

```r
SPARX_TOKENS <- list(
  # Spacing (4px scale)
  spacing = list(xs = "4px", sm = "8px", md = "12px", lg = "16px",
                 xl = "20px", xxl = "32px"),

  # Colors — light mode
  color = list(
    bg_chat = "#fafafa",
    bg_surface = "#ffffff",
    bg_muted = "#f9fafb",
    bg_code = "#0f172a",
    border = "#e5e7eb",
    border_subtle = "#f3f4f6",
    text = "#111827",
    text_muted = "#6b7280",
    text_subtle = "#9ca3af",
    accent = "#2563eb",
    accent_hover = "#1d4ed8",
    accent_bg = "#eef2ff",
    success = "#10b981",
    warning = "#f59e0b",
    danger = "#ef4444",
    tool = "#8b5cf6",
    tool_bg = "#faf5ff"
  ),

  # Dark mode overrides (auto via prefers-color-scheme)
  color_dark = list(
    bg_chat = "#1a1a1a",
    bg_surface = "#262626",
    text = "#f3f4f6",
    # ... (mirror the above)
  ),

  # Typography
  font = list(
    sans = "-apple-system, BlinkMacSystemFont, 'Inter', sans-serif",
    mono = "'SF Mono', Menlo, Monaco, 'Cascadia Code', monospace",
    size_xs = "10px", size_sm = "11px", size_base = "13px",
    size_md = "14px", size_lg = "16px",
    weight_normal = "400", weight_medium = "500", weight_bold = "600",
    line_tight = "1.4", line_normal = "1.55", line_relaxed = "1.7"
  ),

  # Motion
  motion = list(
    fast = "120ms cubic-bezier(0.4, 0, 0.2, 1)",
    normal = "200ms cubic-bezier(0.4, 0, 0.2, 1)",
    slow = "300ms cubic-bezier(0.4, 0, 0.2, 1)"
  ),

  # Radius
  radius = list(sm = "4px", md = "6px", lg = "10px", xl = "12px")
)
```

Every CSS rule references tokens via `{{ token }}` string substitution. One file to edit to reskin the whole app.

## 5. Component redesign

### 5.1 Header (compact provider + settings)

**Before:** two-row strip with full provider dropdown + 3 buttons + token counter.

**After:**
```
┌────────────────────────────────────────────────────────┐
│  ● Claude Sonnet    [⚙]                       1.2K  ⌄ │
└────────────────────────────────────────────────────────┘
```

- Status dot (green = ready / amber = rate-limited / red = error) + model name as a compact pill
- `⚙` gear icon → popover with toggles (Live exec / Auto-install / Git writes), each as a proper switch control
- Token count shown only while streaming; collapses to `⌄` chevron (click to reveal cumulative tokens) when idle
- Click the model pill → provider-swap menu (Anthropic Sonnet / Haiku / Opus, OpenAI GPT-4o / 4o-mini) with a "(no key)" suffix on providers without a configured key

### 5.2 Thread — user bubble, assistant message

**User bubble (unchanged, refined):**
- Right-aligned, blue background, rounded with sharp bottom-right corner (points to user-in-context)
- Max-width 85% (was 85% — no change, just consistent)

**Assistant message:**
- Full width (no "message-from-AI" bubble — assistant text flows freely)
- Left-aligned, normal body text
- Small `◆` marker + "sparx" label at top-left when a new assistant turn starts (helps visual parsing)
- **Rendered markdown**:
  - Headings `#`, `##`, `###` → semantic h4/h5/h6 with appropriate weight
  - Lists (`-`, `1.`) → bullets / numbers with proper indentation
  - Tables (pipe syntax) → styled HTML tables
  - Inline code with syntax color
  - Block code with syntax highlighting (see 5.4)
  - Blockquotes with left border
  - Links clickable, open in system browser via `rstudioapi::viewer()`

**Implementation:** use [`commonmark`](https://cran.r-project.org/web/packages/commonmark/index.html) R package — already widely deployed, no new heavy deps; it gives us CommonMark-to-HTML conversion. For syntax highlighting, use [highlight.js](https://highlightjs.org/) via CDN (8KB CSS + 12KB JS gzipped, one `<script>` tag).

### 5.3 Tool cards — Claude Code-style

**Before:** purple block with icon + name + big wall of text.

**After:** a row that looks like:
```
[▸] ⚙ inspect_data  df                          ✓ 32×11
```
- Collapsed by default (just the summary row)
- Clicking the row expands the full result
- Icon indicates state: spinner during execution, check on success, ⚠ on error
- Inline "summary" of the tool call (dataframe name, file path, search pattern, etc.) — pulled from the tool's `input`
- Right-aligned concise result label (e.g. "32×11" for inspect_data, "0 errors" for run_r_preview, "found 5 matches" for grep_files)

Multi-tool runs then look like:
```
[▸] ⚙ inspect_data  df                          ✓ 32×11
[▸] ⚙ run_r_preview  shapiro.test…              ✗ library(car) not found
[▸] ⚙ run_r_preview  shapiro.test… (retry)      ✓ normality OK
```

Four lines, total vertical space ~80px, each expandable for details.

### 5.4 Code blocks — syntax highlighting + better actions

**Before:** dark mono block + three wrapping text buttons.

**After:**
```
┌─────────────────────────────────┐
│ r   · 12 lines             ⧉   │  ← language label + copy icon button
├─────────────────────────────────┤
│  1  library(tidyverse)          │
│  2  model <- lmer(               │
│  3    bp ~ trt + (1|hosp),      │
│  4    data = trial_data         │  ← highlight.js colored
│  5  )                           │
│  6  summary(model)               │
├─────────────────────────────────┤
│  [↳ Insert]  [▶ Run preview]    │  ← icon buttons, clearer intent
└─────────────────────────────────┘
```

- Language chip (`r`, `python`, `sql`, ...) + line count in header
- Copy → an icon button in the top-right corner (not a text button at the bottom)
- Insert and Run → at the bottom, icon + short label, equal weight
- **Run preview** (new!) uses run_r_preview to execute in sandbox first, shows inline output before the user commits to Run in live session. One-click "try it" without mutating state.

### 5.5 Input area — richer, auto-growing

**Before:** fixed 3-row textarea + Send button.

**After:**
- Auto-growing textarea (starts at 44px / 1 line, grows up to 200px)
- Slash commands (type `/` to open a menu):
  - `/clear` — clear the conversation
  - `/model haiku` — switch model inline
  - `/provider openai` — switch provider
  - `/retry` — retry the last failed call
  - `/plan` — ask the agent to plan before acting
- `@`-mentions:
  - `@df` — forcibly insert a dataframe name into context
  - `@main.R` — attach a file to the message
- Send / Stop button aligned to bottom-right
- Typing keyboard shortcut: `Cmd+Enter` to send (already there)
- Placeholder rotates through stats-specialized hints:
  - "Ask sparx — e.g., fit a mixed model on df"
  - "Ask sparx — e.g., why is my code erroring?"
  - "Ask sparx — e.g., which test for paired pre/post data?"

### 5.6 Welcome / empty state — session-aware

**Before:** static bullet list.

**After:** session-aware greeting:

```
┌─────────────────────────────────────────┐
│  Hey! I see you have 2 dataframes       │
│  loaded: df (32×11), iris (150×5)       │
│                                         │
│  Try asking:                            │
│  → [Summarize df]                       │
│  → [Compare mpg across cyl groups]      │
│  → [What test should I use for iris?]   │
│                                         │
│  Or just describe what you want.        │
└─────────────────────────────────────────┘
```

- Reads `list_dataframes()` at render time
- Generates relevant starter prompts based on what's loaded
- Clicking a suggestion puts the text in the input (user can edit before sending)

### 5.7 Dark mode — RStudio theme sync

Detect RStudio's theme via `rstudioapi::getThemeInfo()`:

```r
theme_info <- tryCatch(rstudioapi::getThemeInfo(), error = function(e) NULL)
is_dark <- !is.null(theme_info) && isTRUE(theme_info$dark)
```

Emit `data-theme="dark"` on the gadget root; CSS uses `[data-theme="dark"] { ... }` with `color_dark` tokens.

### 5.8 Long-running states — progress affordances

- While a tool runs > 3s, show a subtle progress bar in the card (indeterminate stripe)
- While streaming text, show a blinking caret at the end of the text block
- While waiting for rate-limit retry, show a visible countdown ("retrying in 28s") — no raw httr2 progress bars

### 5.9 Keyboard shortcuts

In the gadget:
- `Cmd+Enter` — send
- `Esc` — focus input / abort streaming / close expanded tool card
- `Cmd+K` — clear conversation (with confirm)
- `Cmd+L` — focus input box
- `Cmd+/` — open slash-command menu
- `↑` in empty input — recall last message (like a shell)
- `Cmd+Shift+C` — copy the last assistant response to clipboard

### 5.10 Pop out to window

Add a "↗" button in the header → `shiny::browserViewer()` instead of `paneViewer()`, so users can pop sparx into a full browser window when they want more room.

## 6. Implementation phases

### Phase A — Foundation (day 1)
- `R/ui_tokens.R` (new) — design tokens + helpers
- Rewrite `R/ui.R` chat_css to use tokens exclusively
- Dark-mode detection + CSS overrides
- Verify visual parity with current v0.8.2 baseline

### Phase B — Thread rendering (days 2-3)
- Add `commonmark` dep → Markdown rendering for assistant messages
- Integrate highlight.js (CDN script tag + theme CSS) for code blocks
- Refactor `render_assistant_bubble` to use the new markdown pipeline
- Headings, lists, tables, blockquotes, links

### Phase C — Tool cards (day 4)
- New `render_tool_card` that's collapsible by default
- Summary row shows: tool name, key input, status icon, concise result
- Click-to-expand shows full tool result in a scrollable region
- Group consecutive tool calls into a visual run

### Phase D — Code blocks 2.0 (day 5)
- Language + line count header
- Icon-only Copy button top-right
- Run preview inline (uses existing `run_r_preview` tool)
- Inline preview output appears under the code block

### Phase E — Input area (day 6)
- Auto-growing textarea
- Slash-command popover
- `@`-mention autocomplete for dataframe names
- Rotating placeholder hints
- Last-message recall on `↑`

### Phase F — Welcome + polish (day 7)
- Session-aware welcome with clickable starters
- Pop-out-to-window button
- Keyboard shortcuts
- Long-running state affordances
- Cross-test: 500×400, 800×600, 1200×800

## 7. What we're NOT doing (yet)

These are tempting but out of scope for the overhaul:

- **Conversation history sidebar / multiple conversations** — one conversation per project is enough for v0.9. Multi-conversation UI is a v1.1 feature.
- **Streaming partial tool results** — tool results arrive atomically in the current agent loop. Worth it eventually, not now.
- **Voice input** — the RStudio addin surface doesn't lend itself to voice (no microphone permission flow in Shiny). If we do voice, it's via a separate companion window.
- **Shiny React via @shiny/react** — complete rewrite. Too expensive for the value. Stay with Shiny + vanilla JS.
- **Replace Shiny gadget with pure HTML over `rstudioapi::viewer()`** — more control but we lose the gadget lifecycle we've already built.

## 8. Deliverables

When v0.9 ships:
- 12-point checklist from §3 resolved
- 5 screenshots (light + dark, empty / mid-stream / tool cards / code block / final answer)
- 30-second demo GIF — replace the one in the README
- CHANGELOG entry
- Migration notes (nothing breaking — same API, just nicer shell)

## 9. Success criteria

A non-developer researcher opens sparx for the first time and without reading the README:
1. Sees a friendly session-aware greeting
2. Clicks a suggested starter prompt
3. Watches the agent work through 3-4 tool calls with legible, non-overwhelming visual feedback
4. Reads the final answer with properly-formatted markdown (lists, tables, bold, links)
5. Runs the suggested code with one click
6. Doesn't say "the UI isn't that great honestly"

## 10. Open questions for you

1. **Scope** — do all 6 phases, or pick 3? If 3, I'd pick **B (markdown + syntax highlighting)**, **C (tool cards)**, and **E (input area)** — biggest visual payoff.
2. **commonmark dep** — comfortable adding it? It's CRAN, MIT, 400KB; used by everything from RStudio itself to R Markdown.
3. **highlight.js from CDN vs. bundled** — CDN is 0 bytes to the R package but requires internet during chat. Bundled (prism.js, simpler, 20KB) ships with the package.
4. **Pop-out to browser** — should this open in RStudio's own "View in web browser" or the system browser? The former feels more integrated.
5. **Session-aware starter prompts** — do you want these to be static templates, or should sparx actually make one Claude call on chat-open to generate tailored starters for the loaded session? (The latter costs ~200 tokens per open but feels magical.)

---

*When you give the green light + pick scope, I can ship Phase B + C + E in ~2-3 days of focused work. Full overhaul in a week.*
