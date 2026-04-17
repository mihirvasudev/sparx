# Contributing to sparx

## Current location

For velocity, `sparx` lives as a subdirectory of the [SparsileX monorepo](../) during early development. The plan is to split it into its own standalone repo at `github.com/mihirvasudev/sparx` once the MVP stabilizes.

## Why monorepo for now

- Iterate on the R package + SparsileX web app + agent system prompts in lockstep
- Share the statistical knowledge base
- One source of truth for issues, discussions, contributors
- Easier cross-referencing while the API surface is still changing

## Why split out eventually

- R packages are installed via `remotes::install_github("user/repo")` — cleaner at repo root than subdir
- CRAN requires standalone package structure for submission
- Different contributor pools (R developers vs web developers)
- Independent versioning and release cycles

## How to extract to its own repo (when ready)

Use `git subtree split` to create a new branch containing only the `rstudio-addin/` history:

```bash
# From the SparsileX repo root
git subtree split --prefix=rstudio-addin -b sparx-only

# Push to a new empty GitHub repo
git remote add sparx-repo git@github.com:mihirvasudev/sparx.git
git push sparx-repo sparx-only:main

# The new repo has only rstudio-addin/ files at its root, with history preserved
```

For full history rewriting (if subtree split has issues with renames):

```bash
# Alternative: git filter-repo (requires pip install git-filter-repo)
git clone https://github.com/sparsilex/sparsilex.git sparx-extract
cd sparx-extract
git filter-repo --subdirectory-filter rstudio-addin
git remote add origin git@github.com:mihirvasudev/sparx.git
git push -u origin main
```

Once extracted, keep the `rstudio-addin/` directory in the SparsileX repo as a tracked submodule, or remove it entirely and link to the new repo from the SparsileX README.

## Dev setup

```bash
cd rstudio-addin
R -e 'install.packages(c("devtools", "usethis", "roxygen2", "testthat"))'
R -e 'devtools::install_deps()'
```

In RStudio:
1. `File -> Open Project -> rstudio-addin/`
2. `Build -> Clean and Install`
3. The addins appear under `Addins -> Open sparx Chat` etc.

## Iterating

```r
# After editing R files:
devtools::load_all(".")

# Run tests:
devtools::test()

# Generate docs:
devtools::document()

# Check package:
devtools::check()
```

## Architecture notes

- **No backend dependency.** sparx talks directly to the Anthropic API using the user's BYOK. This keeps the addin self-contained — no sparx-owned server involved.
- **Context-first.** Every request sends editor content, active dataframes, and loaded packages. The system prompt instructs Claude to reason about this specific session, not generic R.
- **Stats-specialized.** The system prompt bakes in assumption checking, effect-size reporting, and idiomatic tidyverse preferences. This is the wedge vs generic Copilot.

## Code style

- Use `<-` not `=` for assignment
- Snake_case for function names
- Document exported functions with roxygen2
- Keep R files < 300 lines; split when they get larger
- No dependencies beyond what's already in DESCRIPTION unless justified
