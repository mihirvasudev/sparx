# sparx — Changelog

## v0.9.0 — UI/UX overhaul

Huge visual + interaction upgrade driven by real-world testing of v0.8.

**Thread rendering**
- Full GitHub-flavored markdown rendering via **commonmark** (headings, lists,
  tables, blockquotes, links, inline code)
- Syntax-highlighted code blocks via **Prism.js** (R, Python, SQL, Markdown)
  — assets bundled offline in `inst/www/`
- Code blocks now have a language chip + line count header, icon-only Copy
  button in the top-right, and improved Insert / Run buttons below
- Assistant messages show a subtle `● sparx` sender label instead of a bubble

**Tool cards — Claude-Code-style**
- Tool results are now collapsible rows:
  `[▸] ✓ inspect data  df                          32×11`
- Click to expand the full result (scrollable, 300px max)
- Concise input preview pulled from tool's `input` (dataframe name, file
  path, search pattern, etc.)
- Running tools show an inline spinner; errors get a red status label

**Input area**
- Auto-growing textarea (1 line → 160px max, grows as you type)
- **Slash commands**: `/clear`, `/model haiku`, `/provider openai`, `/retry`,
  `/help` — menu pops up as you type `/`
- `↑` in empty input recalls your last message (shell-style)
- `Esc` aborts streaming
- Rotating placeholder hints

**Welcome screen — session-aware**
- Reads `.GlobalEnv` on open and tailors starter prompts to loaded data
- "I see you have `df` loaded (32×11). Try: [Summarize df and…]"
- Clickable starters populate the input

**Design system**
- New `R/ui_tokens.R` — single source of truth for spacing / color / type
- CSS variables for light + dark palettes
- `rstudioapi::getThemeInfo()` detection — sparx automatically matches your
  RStudio theme (dark mode supported end-to-end)

**Controls bar**
- Compact single-row layout with a model pill (Claude Sonnet, GPT-4o, etc.)
- Three mode toggles: Live / Install / Git — now clearly labeled
- Token usage on the right, shown as `1.2k in / 340 out` only when non-zero

**Fixes**
- `get_api_key()` no longer hangs in non-interactive sessions (env var
  checked before keyring, keyring skipped when `!interactive()`)
- ANSI color codes from httr2 retry progress no longer leak into the pane
- Auto-scroll only triggers when user is near the bottom (won't yank you
  back while reading earlier messages)

**Tests**: 269 assertions across 9 test files, all passing.

---

## v0.8.2 — Real-world polish

- Fixed aggressive auto-scroll (was fighting users scrolling up)
- Compacted controls bar to a single 28px row (was ~60px)
- Suppressed httr2 ANSI color codes from retry progress display

## v0.8.1 — First end-to-end fix

- Fixed `tools.8.custom.input_schema.properties` HTTP 400 from Anthropic
  (three tools had `properties = list()` → `[]` instead of `{}`)
- Caught by the first real agent call

## v0.8.0 — Model-agnostic

- Added OpenAI (GPT) support alongside Anthropic
- Provider abstraction layer + dropdown in the chat UI
- Per-provider API key storage in the system keyring
- `sparx::set_provider("openai")` to switch active provider

## v0.7.0 — UX toggles + runtime state

- Gadget header: Live exec / Auto-install / Git writes toggles
- Stop button (flag-based abort between tool calls)
- Cumulative token usage display
- `git_commit` tool (opt-in)
- Rate-limit retry with `Retry-After` honoring

## v0.6.0 — Persistence + web + git

- Conversations persist to `<project>/.sparx/conversation.json`
- `fetch_url` tool for HTTPS page fetching
- Git tools: status / diff / log
- Auto `.gitignore` inside `.sparx/` directory

## v0.5.0 — Live-session execution

- `run_in_session` tool (opt-in, destructive-pattern blocklist)
- `get_session_state` tool
- Fixed `<<-` scoping issue inside `withCallingHandlers`

## v0.4.0 — Plot vision + diffs + todos

- `inspect_plot` tool → captures last plot, sends to Claude as vision input
- `edit_file` result renders as +/- diff
- `todo_write` tool + visible task checklist in the chat header

## v0.3.0 — File ops

- Full file system tools: `list_files`, `read_file`, `grep_files`,
  `write_file`, `edit_file`
- Project-root sandbox enforcement (no `..`-traversal)
- Auto error recovery via `is_error` on tool results

## v0.2.0 — Agentic loop

- Agentic loop with tool use (max 12 iterations)
- 4 foundational tools: `inspect_data`, `check_package`, `run_r_preview`,
  `read_editor`
- Sandboxed preview execution via `callr::r()`

## v0.1.0 — First MVP

- RStudio addin scaffolding
- BYOK API key via system keyring
- One-shot chat gadget in the Viewer pane
- Streaming SSE to Anthropic
