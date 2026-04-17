# sparx

> **Claude Code-style AI pair-programmer for RStudio.** Specialised for statistics in medical and biomedical research. Free, open-source, BYOK. Works with Claude *or* GPT.

[![R package](https://img.shields.io/badge/R%20package-1.0.0-blue.svg)](https://github.com/mihirvasudev/sparx)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

## Why sparx

If you've used Claude Code or Cursor, this is the R equivalent — but baked in to RStudio. Describe what you want in English. sparx reads your data, writes the code, runs it in a sandbox, fixes errors, and hands you a verified result with Insert / Run buttons.

### sparx vs Posit Assistant

Posit's own AI assistant is excellent. If your institution happily pays the subscription, use it. sparx is for everyone else:

|  | Posit Assistant | sparx |
|---|---|---|
| **Cost** | $20/month subscription | Free (BYOK — you pay only the model provider's API usage) |
| **Providers** | Anthropic only | Anthropic **or** OpenAI, switchable mid-session |
| **Source** | Closed, proprietary | MIT open source, fork-friendly |
| **Data path** | Your machine → Posit → Anthropic | Your machine → provider, directly |
| **Target** | General R users | Stats-specialised (medical research, biostats) |

A 30-minute research session on sparx typically costs **$0.20 – $0.80** in API usage on default models.

## Install

In the **RStudio Console**, paste these two lines:

```r
install.packages("remotes")
remotes::install_github("mihirvasudev/sparx")
```

That installs sparx and everything it needs. Then: **Session → Restart R** (`Cmd+Shift+F10`).

Verify:
```r
packageVersion("sparx")
# [1] '1.0.0'
```

## First run

### Option A: the one-liner demo

```r
sparx::demo_workflow()
```

This loads a simulated blood-pressure trial dataset and opens the chat with a pre-filled prompt. If you don't have an API key yet, the chat will show you how to get one. **Fastest way to see sparx in action.**

### Option B: bring your own data

1. Get an API key from **one** provider:
   - **Anthropic (Claude)** — [console.anthropic.com](https://console.anthropic.com) — recommended for stats
   - **OpenAI (GPT)** — [platform.openai.com/api-keys](https://platform.openai.com/api-keys) — works just as well, often cheaper

2. Store it (the key is encrypted in your system keychain — never touches disk as plaintext):
   ```r
   sparx::set_api_key()                       # for Anthropic
   sparx::set_api_key(provider = "openai")    # for OpenAI
   # You can store both — switch from the chat dropdown
   ```
   macOS will prompt for Keychain access once. Click **Always Allow**.

3. Open the chat:
   ```r
   sparx::open_chat()
   # Or: Addins menu → Open sparx Chat
   ```
   Bind to `Cmd+Shift+A` via **Tools → Modify Keyboard Shortcuts → Addins** for a permanent keybinding.

4. Type a question. Click **Run** on the suggested code.

## What sparx can do

19 tools the agent uses autonomously:

| | Category | Tools |
|---|---|---|
| 📊 | Data & session | `inspect_data`, `check_package`, `read_editor`, `run_r_preview` (sandboxed), `run_in_session` (live, opt-in), `get_session_state`, `inspect_plot` (via vision) |
| 📁 | File system | `list_files`, `read_file`, `grep_files`, `write_file`, `edit_file` (with visible diffs) |
| 🔀 | Git | `git_status`, `git_diff`, `git_log`, `git_commit` (opt-in) |
| 🌐 | Web | `fetch_url` (HTTPS only) |
| 📋 | Workflow | `install_packages` (opt-in), `todo_write` (multi-step tracker) |

Plus: vision on your Plots pane, CommonMark + Prism syntax-highlighted responses, session-aware welcome, persistent conversations per project, light and dark mode, slash commands (`/model haiku`, `/clear`, `/retry`, ...), session keychain storage.

## A realistic session

> 💬 *"Test whether blood-pressure reduction differs across the three treatment groups in trial_demo, adjusting for age. Check assumptions. Report effect size."*

sparx:
1. **Inspects `trial_demo`** → 120 rows, 7 cols, treatment is a 3-level factor
2. **Checks `lme4`** → installed, v1.1.35.5
3. **Runs a preview** of an ANCOVA in an isolated subprocess → verifies it works
4. **Checks assumptions** — normality, homogeneity of variance — runs Shapiro-Wilk and Levene's
5. **Presents** a 3-sentence explanation + a single R code block with **Insert / Run / Copy**
6. You click **Run** — the result lands in your R console

Typical cost: **$0.01 – $0.02** per message, ~4 messages per task.

## Privacy & safety

sparx sends your prompts, your code, and dataframe **schemas** (column names + types — not row data) to the model provider (Anthropic or OpenAI) over HTTPS. Claude/GPT can see what your code does but doesn't see your actual patient rows unless you explicitly ask sparx to include them.

**Do not use sparx on PHI/PII unless your institution has a Business Associate Agreement (BAA) with the model provider.** Anthropic and OpenAI both offer BAAs on their Enterprise tiers. Neither is HIPAA-compliant by default.

Other safety defaults:
- BYOK model — your key goes directly from your machine to the provider. sparx has no servers.
- File operations are sandboxed to your project root; `..` traversal is blocked.
- Live-session execution is **off by default**; must be turned on per-session.
- Destructive patterns (`rm(list=ls())`, `unlink`, `system`, `source("http…")`, etc.) are refused even when live mode is on.
- Three opt-in toggles (Live exec, Auto-install, Git writes) — all default off.
- Conversations are stored locally at `<project>/.sparx/conversation.json`, with an auto-created `.gitignore` to avoid leaks.

## Troubleshooting

### "there is no package called 'remotes'"
Run `install.packages("remotes")` first. Then retry the install.

### "Your API key was rejected"
Either the key is wrong, revoked, or for the wrong provider. Fix:
```r
sparx::set_api_key()                       # Anthropic
sparx::set_api_key(provider = "openai")    # OpenAI
```

### Rate limit errors (HTTP 429)
New accounts have tight per-minute caps. Easy fix — switch to a cheaper model:
```r
options(sparx.model = "claude-haiku-4-5-20251001")
```
…or wait ~60 seconds and hit Send again. sparx auto-honors `Retry-After` headers.

### Keychain won't accept the key
Use an environment variable instead:
```r
# Permanent: add to ~/.Renviron
# ANTHROPIC_API_KEY=sk-ant-...

# Or for this session:
Sys.setenv(ANTHROPIC_API_KEY = "sk-ant-...")
```

### Chat pane shows weird characters / colors
Fixed in v0.9.0 — `remotes::install_github("mihirvasudev/sparx", force = TRUE)` and **Restart R**.

### Chat won't open / "no package called 'sparx'"
Restart R after install (`Session → Restart R` or `Cmd+Shift+F10`). R caches loaded namespaces.

### Network / proxy issues in a hospital
If you're behind a corporate proxy:
```r
Sys.setenv(https_proxy = "http://your-proxy:port")
```

### Something else?
Open an issue: https://github.com/mihirvasudev/sparx/issues

## Models and costs

| Provider | Model | ~Cost/message | When to use |
|---|---|---|---|
| Anthropic | claude-sonnet-4-5 (default) | $0.005 – $0.02 | Best quality, best reasoning |
| Anthropic | claude-haiku-4-5 | $0.001 – $0.004 | Fast, cheap, ~80% as good for stats |
| OpenAI | gpt-4o | $0.005 – $0.02 | Competitive with Sonnet |
| OpenAI | gpt-4o-mini | $0.001 – $0.004 | Competitive with Haiku |

Switch with `/model haiku` (etc.) in the chat input, or:
```r
options(sparx.model = "claude-haiku-4-5-20251001")
```

## Keyboard shortcuts

In the chat:
- `Cmd/Ctrl + Enter` — send
- `Esc` — stop the agent (when streaming)
- `↑` (in empty input) — recall last message
- `/` — open slash-command menu

Slash commands: `/clear`, `/model haiku`, `/provider openai`, `/retry`, `/help`.

## Contributing

PRs welcome. See [CONTRIBUTING.md](./CONTRIBUTING.md) for dev setup. Tests: 269 assertions across 9 files (`devtools::test()`).

## Roadmap

- **v1.1** — context compaction (for very long conversations), inline per-call approval for live execution, multi-conversation sidebar
- **v1.2** — RMarkdown / Quarto notebook awareness, plan mode
- **v2.0** — Integrates with SparsileX (the standalone web app for non-coder researchers — same agent brain, different surface)

Related:
- [SparsileX](https://github.com/mihirvasudev/sparsilex) — AI-native stats web app (early alpha)
- Inspired by [Claude Code](https://claude.com/claude-code) and [Clicky](https://github.com/farzaa/clicky)

## License

MIT © 2026 Mihir Curovana.
