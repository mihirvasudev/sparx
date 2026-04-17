# sparx

> **Claude Code-style AI pair-programmer for RStudio.** Describe what you want in English. sparx reads your data, writes the code, runs it, fixes errors, and hands you a verified result.

[![R package](https://img.shields.io/badge/R%20package-0.7.0-blue.svg)](https://github.com/sparsilex/sparx)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

## What it is

sparx is an RStudio addin that brings an **agentic AI assistant** into your IDE. Unlike autocomplete tools, sparx has **19 tools** for reading your data, your files, your R session, the web, and git — and it uses them iteratively to ship a working answer.

Specialized for **statistical workflows in medical and biomedical research**.

## What makes it different

- **Agentic loop, not just autocomplete** — sparx can inspect, plan, run, verify, and iterate in a single turn
- **Reads your session** — current dataframes, loaded packages, open scripts, plot output
- **Project-aware file system** — list/read/grep across your project; targeted edits with visible diffs
- **Runs code two ways** — sandboxed preview for verification, live session (opt-in) for state changes
- **Statistical rigor baked in** — system prompt enforces assumption checks, effect sizes, idiomatic R
- **Everything stays local** — BYOK (your Anthropic key), system-keyring storage, no sparx-owned servers
- **Conversations persist** — resume where you left off, per project

## Install

```r
# install.packages("remotes")
remotes::install_github("sparsilex/sparx")
```

## Setup

1. Get an Anthropic API key: [console.anthropic.com](https://console.anthropic.com)

2. Store it securely (one-time):
   ```r
   sparx::set_api_key()
   # Prompts for your key; saved in your system keyring
   ```

3. Open RStudio → **Addins** → **Open sparx Chat**
   - Or bind `Cmd+Shift+A` via **Tools → Modify Keyboard Shortcuts**

4. Optional: grant advanced capabilities via the toggles in the chat header
   - **Live exec** — sparx can run code in your real R session (destructive patterns still blocked)
   - **Auto-install** — sparx can run `install.packages()` on your behalf
   - **Git writes** — sparx can create git commits (never auto-pushed)

## The 19 tools

### Session & data
| Tool | What it does |
|------|---|
| `inspect_data` | Structure + sample rows of a dataframe |
| `check_package` | Confirm a package is installed + version |
| `read_editor` | Read lines from the active editor |
| `run_r_preview` | Execute code in an isolated subprocess (safe preview) |
| `run_in_session` | Execute code in your live R session (opt-in) |
| `get_session_state` | Summary of all `.GlobalEnv` objects |
| `inspect_plot` | See the current plot using Claude's vision |

### File system (project-scoped)
| Tool | What it does |
|------|---|
| `list_files` | Glob-match files in the project |
| `read_file` | Read a text file with line numbers |
| `grep_files` | Regex search across the project |
| `write_file` | Create a new file |
| `edit_file` | Targeted find-and-replace with a visible +/- diff |

### Git
| Tool | What it does |
|------|---|
| `git_status` | Short status + branch |
| `git_diff` | Working-tree or staged diff |
| `git_log` | Recent commits (oneline) |
| `git_commit` | Create a commit (opt-in) |

### Web + workflow
| Tool | What it does |
|------|---|
| `fetch_url` | Fetch an HTTPS page and return cleaned text |
| `install_packages` | Install from CRAN (opt-in) |
| `todo_write` | Maintain a visible checklist for multi-step work |

## Example: worked session

> "Fit a mixed-effects model on trial_data where bp_reduction depends on treatment and age, with hospital_id as a random effect. Check assumptions and report properly."

sparx:
1. **inspect_data(trial_data)** — "150 rows × 8 cols, treatment is a 2-level factor, bp_reduction is numeric..."
2. **check_package("lme4")** — "installed, v1.1.35.5"
3. **run_r_preview** — verifies `lmer(bp_reduction ~ treatment + age + (1|hospital_id), data = trial_data)` runs without error
4. **run_r_preview** — runs `performance::check_model(model)` to validate assumptions
5. **inspect_plot** — reads the diagnostic plots; flags one outlier in the QQ plot
6. Presents: a 3-sentence explanation + one code block with Insert / Run / Copy buttons

Click Run → result appears in your R console. Typical cost: **$0.005–$0.02 per message** on Claude Sonnet.

## Right-click actions

Select any code in your editor, right-click, and pick:
- **Explain Selection** — plain-English walkthrough of the code
- **Fix Selection** — sparx diagnoses what's wrong and patches it
- **Improve Selection** — rewrite in idiomatic tidyverse R

## Keyboard

In the chat input:
- `Cmd/Ctrl + Enter` — send

## Privacy & security

- Your API key is stored in your **system keyring** (macOS Keychain / Windows Credential Locker / gnome-keyring) via the `keyring` package. Never touches disk as plaintext.
- Requests go directly from your machine to `api.anthropic.com`. No sparx server involved.
- Dataframe **rows are never sent** — only column names, types, and dimensions. (Exception: if you explicitly ask sparx to write code that references specific values.)
- Code in your editor **is** sent as context (that's the whole point). Don't use sparx on sensitive/proprietary code you don't want Anthropic to see.
- File writes are scoped to the project root — sparx will refuse `..` traversal or absolute paths outside the project.
- Live execution blocks destructive patterns: `file.remove`, `unlink`, `rm(list=ls())`, `system()`, `source("http...")`, etc.
- Three opt-in toggles (Live exec, Auto-install, Git writes) are all **default off**.

## Conversations persist

Your chat history is saved to `<project>/.sparx/conversation.json` and automatically reloaded when you open the chat next time. An `.sparx/.gitignore` is written to ensure conversations don't leak into commits.

Clear a conversation with the "Clear" button in the chat header.

## Typical costs

| Model | ~Cost per message |
|---|---|
| claude-sonnet-4-5 (default) | $0.005 – $0.02 |
| claude-haiku-4-5 | $0.001 – $0.004 |

Switch model:
```r
options(sparx.model = "claude-haiku-4-5-20251001")
```

A 30-minute research session with 20–30 tool calls: typically $0.20–$0.80.

## Contributing

PRs welcome. See [CONTRIBUTING.md](./CONTRIBUTING.md) for dev setup. Tests run with `devtools::test()` — 236+ assertions across 8 test files.

Related:
- [SparsileX](https://github.com/sparsilex/sparsilex) — the standalone AI-native stats web app
- Inspired by [Clicky](https://github.com/farzaa/clicky) and [Claude Code](https://claude.com/claude-code)

## License

MIT © 2026 Mihir Curovana
