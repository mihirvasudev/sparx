# Production Readiness Assessment — sparx v0.9 → v1.0

**Honest status**: v0.9.0 works end-to-end on the developer's machine. It
isn't ready yet to hand to a researcher who has never seen it before.

## The test: the AIIMS Delhi med student scenario

Hypothetical: a med student (our exact target user) clicks a link, follows
the README, and 10 minutes later makes their first analysis. What breaks?

| Step | Risk level | What could go wrong |
|---|---|---|
| 1. Click GitHub link | Low | Repo is public, README clear ✓ |
| 2. Run `remotes::install_github(...)` | **High** | They don't have `remotes` installed. We hit this ourselves. |
| 3. After install, open chat | Medium | `sparx::open_chat()` works, but no instruction on *what* to type first |
| 4. Enter API key | **High** | What if they don't have one? No signup flow. Where to get it? |
| 5. Get first response | Medium | Rate limits on a new Anthropic account are tight — they may hit 429 on prompt 2 |
| 6. Try ChatGPT instead | Medium | `set_api_key(provider = "openai")` works but it's buried |
| 7. Run the suggested code | Low | Insert / Run buttons work ✓ |
| 8. Hit an error | **High** | Error messages aren't user-friendly; no "here's what to do" guidance |
| 9. Privacy concern | **Critical** | Data goes to Anthropic/OpenAI. We don't say this prominently. For med research this is a HIPAA/ethics conversation. |

Five "High" or "Critical" risks → **not ready yet**.

## What's missing for v1.0

### P0 — Blocks sharing with a real user

1. **Install-path bulletproofing**
   - Add `install.packages("remotes")` to the instructions explicitly
   - One-line copy-pasteable install that handles the dep chain
   - Test from a truly clean R install

2. **First-run onboarding**
   - The current welcome card shows "I see you have no dataframes." For a
     new user that's not helpful.
   - Better: if no API key, show the key setup flow visually. If no data,
     suggest `data(mtcars)` + open chat.
   - Clear "here's your first prompt" example

3. **Privacy disclaimer — prominent**
   - README top: "sparx sends your code and data schemas to
     Anthropic/OpenAI. Do not use on PHI/PII unless your institution
     has a BAA with them."
   - In-app: one-line note in the welcome card
   - Link to Anthropic's/OpenAI's privacy policies

4. **Error message humanization**
   - HTTP 401 → "Your API key was rejected. Run `sparx::set_api_key()` to update it."
   - HTTP 429 → "Rate limited. Either wait a minute or run `options(sparx.model = 'claude-haiku-4-5-20251001')` to use a cheaper/higher-limit model."
   - Keyring error → "Could not access Keychain. Try `Sys.setenv(ANTHROPIC_API_KEY = '...')` instead."
   - Network error → clear "Check your internet connection"

5. **Troubleshooting section in README**
   - 5-6 most likely issues with fixes
   - Known compatibility: R version, RStudio version, macOS/Windows/Linux

6. **README polish**
   - A demo GIF (or at minimum a rich ASCII walkthrough)
   - "Why not just use Posit Assistant?" FAQ row
   - Screenshots of each key feature (welcome, tool cards, code block, markdown output)
   - Cost breakdown that's concrete (a real session, real tokens, real dollars)

7. **Medical research-specific demo**
   - A clinical-trial-like demo dataset shipped with the package
   - `sparx::demo_workflow()` function that walks through a full research flow
   - Gives the user something concrete to try

### P1 — Nice to have before launch

8. **CI/CD basics**
   - GitHub Actions workflow: run tests on push
   - R CMD check (even if not CRAN-bound)
   - At least one contributor doc

9. **Distribution**
   - Tag v1.0.0 on GitHub for pinnable installs
   - Simple landing page (could be just the README rendered well)
   - Twitter/X post with the demo GIF

10. **Observability**
   - Optional telemetry for usage patterns (user opts in) — with a
     clear disclosure. Or just rely on GitHub stars / issues.

### P2 — Can wait for v1.1+

- CRAN submission (man/, vignette, pkgdown)
- Plan mode
- Multi-conversation / conversation search
- Windows/Linux explicit testing + platform-specific docs
- i18n (Hindi UI?)

## Execution order

Doing all P0 items today:

1. Bulletproof install (15 min)
2. First-run onboarding (30 min)
3. Error humanization (30 min)
4. Privacy disclaimer (15 min)
5. README rewrite (45 min)
6. Troubleshooting guide (15 min)
7. Demo workflow function (30 min)
8. Clean install smoke test (15 min)
9. Bump v1.0.0, tag, push (10 min)

Total: ~3.5 hours of focused work → v1.0.0 shippable.

## Definition of "production-ready for sharing"

A researcher who's never seen sparx can:

- [ ] Install it in ≤5 minutes from reading only the README
- [ ] Get their first agent response in ≤10 minutes of total effort
- [ ] Understand the privacy tradeoff before sending sensitive data
- [ ] Hit any error and know what to do next
- [ ] Know how to reach us (GitHub issues) if they're stuck

When all five are true, we ship v1.0 and DM the AIIMS link.
