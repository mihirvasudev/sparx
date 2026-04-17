# sparx

> AI pair-programmer for RStudio. Describe what you want in English; sparx writes the R.

[![R-CMD-check](https://img.shields.io/badge/R%20package-0.1.0-blue.svg)](https://github.com/sparsilex/sparx)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

## What it does

sparx is an RStudio addin that brings Claude-powered pair-programming directly into your IDE. It reads your open script, your active dataframes, and your loaded packages — then generates R code you can insert or run with one click.

Specialized for **statistical workflows in medical and biomedical research**:

- Pick and run the right statistical test for your data
- Check assumptions before analyses
- Write `lme4`, `survival`, `lavaan`, `BayesFactor` code without memorizing APIs
- Debug errors by reading the full script context
- Explain complex code in plain English

## Install

```r
# install.packages("remotes")
remotes::install_github("sparsilex/sparx")
```

## Setup

1. Get an Anthropic API key from [console.anthropic.com](https://console.anthropic.com).

2. Store it securely (one-time setup):

   ```r
   sparx::set_api_key()
   # You'll be prompted to paste your key — it's stored in your system keyring
   ```

3. Open RStudio. You'll see **sparx** entries under **Addins**:
   - **Open sparx Chat** — the main chat panel
   - **Explain Selection** — select code, run this to get a plain-English walkthrough
   - **Fix Selection** — AI diagnoses and fixes the selected code
   - **Improve Selection** — idiomatic rewrite of the selected code

4. (Optional) Bind **Open sparx Chat** to a keyboard shortcut via **Tools → Modify Keyboard Shortcuts** (try `Cmd+Shift+A`).

## Using sparx

### Main chat

Click **Addins → Open sparx Chat** (or press your keybinding). A chat panel opens in the Viewer pane.

Type a request:

> fit a mixed-effects model for bp_reduction, with treatment and age as fixed effects and hospital_id as a random effect

sparx will:
1. Read your active dataframes and loaded packages
2. Stream back an explanation + R code
3. Show **Insert** / **Run** / **Copy** buttons on each code block

Click **Insert** to place the code at your cursor; **Run** to execute it in your R console; **Copy** to clipboard.

### Fixing errors

Select the line that errored (or the whole broken function), right-click, and choose **sparx → Fix Selection**. sparx reads the code + any surrounding context and proposes a fix.

### Keyboard shortcuts

In the chat input, press **Cmd/Ctrl + Enter** to send.

## Context sparx sees

On every request, sparx reads:

- Your current editor document (path + content)
- Cursor position and any selection
- Every dataframe in your global environment (name, row/col counts, column types — **not** the actual data rows)
- Currently loaded packages
- R version

Your **data is never sent** — only schemas. Code in the editor is sent as context.

## API costs

sparx uses Anthropic's API directly with your own key. Typical usage:

- Each request sends ~1K-4K input tokens (script + context + system prompt)
- Generates ~200-600 output tokens per response
- At Claude Sonnet 4.6 pricing (~$3/MTok in, $15/MTok out), that's roughly **$0.005-0.02 per message**
- A typical 30-minute research session: **$0.15-0.50**

Switch to a cheaper model any time:

```r
options(sparx.model = "claude-haiku-4-5-20251001")
```

## Privacy

- Your API key is stored in your **system keyring** (macOS Keychain, Windows Credential Locker, gnome-keyring on Linux) via the `keyring` package. It never touches disk in plaintext.
- All API requests go directly from your machine to Anthropic. No sparx-owned servers involved.
- Data in your dataframes is **not** sent — only column names, types, and dimensions.
- Your code **is** sent to Anthropic as context. If that's unacceptable for your use case, don't use sparx on sensitive code.

## Contributing

PRs welcome. See [CONTRIBUTING.md](./CONTRIBUTING.md) for development setup.

Related:
- [SparsileX](https://github.com/sparsilex/sparsilex) — the standalone AI-native stats web app that sparx is an extension of
- Inspired by [Clicky](https://github.com/farzaa/clicky) — Farza's AI screen companion

## License

MIT © 2026 Mihir Curovana
