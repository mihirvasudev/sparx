# Testing sparx locally

## What's already set up on your machine

✅ **R 4.4.2** — already installed (from the R.pkg installer earlier)
✅ **R dependencies** — shiny, miniUI, httr2, jsonlite, keyring, glue, rstudioapi all installed
✅ **sparx 0.8.0** — already installed in your system R library

## What you still need: **RStudio Desktop**

sparx is a **RStudio addin** — it runs as a Shiny gadget inside the RStudio IDE's Viewer pane. It needs the actual RStudio application to work.

### Install RStudio

Download RStudio Desktop (free) from:
- **https://posit.co/download/rstudio-desktop/**

Or via Homebrew:

```bash
brew install --cask rstudio
```

Install takes about 2 minutes.

## Once RStudio is installed

### 1. Open RStudio, then store at least one API key

In the RStudio Console, paste:

```r
# For Anthropic (Claude):
sparx::set_api_key()
# You'll be prompted — paste your sk-ant-... key

# For OpenAI (GPT):
sparx::set_api_key(provider = "openai")
# You'll be prompted — paste your sk-... or sk-proj-... key

# You can do both. Keys are encrypted in your system keyring (macOS Keychain).
```

### 2. Open the chat

Three ways:

**A. Addins menu**
```
Addins → Open sparx Chat
```

**B. Keyboard shortcut** (recommended)
- `Tools → Modify Keyboard Shortcuts → Addins`
- Find **"Open sparx Chat"**, bind it to `Cmd+Shift+A`
- Now you can open the chat from anywhere with that shortcut

**C. Console**
```r
sparx::open_chat()
```

The chat opens as a pane in the Viewer area.

### 3. Try the first prompt

Load some data first so sparx has something to work with:

```r
# In RStudio Console:
data(mtcars)
df <- mtcars
df$cyl <- as.factor(df$cyl)
```

Now in the sparx chat, type:

> Test whether mpg differs significantly across cyl groups. Check assumptions properly.

You should see, in order:
1. A tool badge: **Inspecting data** (Claude calls `inspect_data("df")`)
2. A tool badge: **Checking package** (maybe)
3. A tool badge: **Running R code (preview)** (verifies the code works)
4. A short explanation + a code block with Insert / Run / Copy buttons

Click **Run** — the code executes in your R console. Done.

### 4. Try more things

**Right-click on selected code** → Addins menu → **Explain Selection** / **Fix Selection** / **Improve Selection**

**Toggles** in the chat header (all default off):
- **Provider**: Anthropic ↔ OpenAI dropdown
- **Live exec**: sparx runs code directly in your session
- **Auto-install**: sparx can call `install.packages()` for you
- **Git writes**: sparx can create commits

**Plot vision**: generate a plot in RStudio, then ask:
> What does my current plot look like? Any issues?

Claude will use the `inspect_plot` tool to capture the Plots pane and see it via vision.

**File ops**: ask sparx to refactor a script:
> Find the function in my project that fits the linear model and add covariates for age and sex.

sparx uses `grep_files`, `read_file`, `edit_file` to do this — and shows you a diff in the chat.

## If something's broken

### Chat won't open

```r
# Check the install:
library(sparx)
packageVersion("sparx")  # should be 0.8.0

# Reinstall from GitHub if needed:
remotes::install_github("mihirvasudev/sparx")
```

### "No API key found"

```r
sparx::set_api_key()                       # Anthropic
sparx::set_api_key(provider = "openai")    # OpenAI
```

If keyring gives trouble, set env var instead:

```r
Sys.setenv(ANTHROPIC_API_KEY = "sk-ant-...")
Sys.setenv(OPENAI_API_KEY = "sk-...")
```

### Rate limit errors

sparx auto-retries with exponential backoff + honors `Retry-After`. If you still hit limits, switch to a cheaper model:

```r
options(sparx.model = "claude-haiku-4-5-20251001")       # if Anthropic
options(sparx.openai_model = "gpt-4o-mini")              # if OpenAI
```

### Want to see what sparx sees

Every tool call is visible in the chat as a purple badge. Click it (when collapsible UI is added in v0.9) to see the raw input/output.

## Reinstalling after code changes

If you're iterating on the sparx source (this repo):

```bash
# From /Users/mihir/SparsileX:
R CMD INSTALL rstudio-addin
```

Then restart R in RStudio: `Session → Restart R` (or `Cmd+Shift+F10`).

## Costs

A typical 30-minute research session: **$0.20 – $0.80** on default models.
Tool calls are visible at the top of the chat header (Tokens: N,NNN in, N,NNN out).
