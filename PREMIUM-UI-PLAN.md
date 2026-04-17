# sparx — Premium UI/UX Overhaul

**Target:** v1.2.0
**Scope:** Rebuild the look and feel to Claude.ai / Linear / Raycast quality inside the RStudio Viewer pane.
**Non-goals:** No React rewrite. No new runtime dependencies. Same Shiny-gadget shell.

## Why

v1.1.0 is feature-complete but still feels "functional Shiny app." The user test of v0.9.0 ("the UI isn't that great honestly") still applies to v1.1.0 in spirit — we added capability, not polish. This overhaul ships the polish.

## The 10 pillars

### 1. Layout & density
- Title bar 40px: `✦ sparx` logo (left) · model picker · icon toggles · Clear/Close (right)
- **Delete the separate controls bar.** Model + toggles consolidate into one row.
- Thread ≥75% of vertical space.
- Input is one floating card with embedded Send button (Claude.ai pattern).

### 2. Typography
- Bump body from 13→14px, line-height 1.6
- Clearer scale: 11 / 12 / 14 / 15 / 17 / 20 / 28
- Use Inter / SF where available, with monospace JetBrains-Mono-style fallback
- Hierarchy drives visual parsing, not bubbles and borders

### 3. Tool cards (Claude Code style)
- No heavy card. Horizontal row, subtle bottom separator.
- Grid: `icon · name · args-preview · status-dot · duration`
- Colored status dot (green=ok, amber=running with pulse, red=error) instead of symbols
- Click the row to expand details; chevron on the left
- Per-tool-category icon colors (read=blue, write=violet, git=emerald, web=amber)

### 4. Message layout
- **Drop the assistant "bubble."** Just prose with natural padding.
- User message: compact right-aligned pill, 85% max-width, subtle shadow
- Remove "● sparx" sender label — alignment + tool cards already convey structure
- Timestamps: ultra-subtle on hover only

### 5. Code blocks
- Warm-black background (`#0c0a09`), not jet (`#0f172a` was too cool-blue)
- Language chip top-left: `r`, `python`, `sql`
- Copy icon **top-right, only on hover**
- Actions row at bottom: `Insert` (ghost) · `▶ Run` (solid green) · `Copy` (ghost)
- `border-radius: 8px`, subtle outer shadow instead of hard border

### 6. Header (consolidated)
- `✦ sparx` logo mark in accent color
- Model picker as a pill: `Claude Sonnet ⌄` — clicking reveals a menu that combines model + provider switch
- 4 toggles as tiny colored pills: off = gray outline, on = colored fill (Plan=blue, Live=green, Install=amber, Git=violet)
- `· · ·` kebab menu for Clear conversation
- Token count in micro-type at the far right, only visible after first API call

### 7. Input area
- Elevated white card with 1px border
- Auto-grows 44px → 200px
- Send button embedded in the bottom-right of the card (not outside)
- Focus state: soft glow (`box-shadow: 0 0 0 3px accent-bg`) — no harsh outline
- Bottom hint shrinks when the card is focused, grows when idle

### 8. Welcome / first run
- Big `✦` logo mark, centered
- `sparx` in 20px bold
- `AI research partner for R` as subtitle
- Session-aware intro as plain text (no card)
- Starter prompts as clean horizontal items with `→` prefix (Raycast style)
- Privacy note as subtle ghost text at bottom, not a card

### 9. Motion
- Messages fade-in-up 180ms on arrival (eases the jank of reactive updates)
- Tool card expand: CSS grid trick (0fr → 1fr) for smooth accordion without measuring
- Send ↔ Stop button: opacity crossfade 150ms
- Input focus ring: 200ms ease-out
- Status dot pulse: 1.2s infinite while running

### 10. Polish details
- Header gains a `box-shadow: 0 1px 2px rgba(0,0,0,0.04)` when thread scrolled past 10px
- Scrollbar refined: 6px thumb, 3px radius, transparent track
- `::selection` uses accent color
- Focus rings on all interactive elements (accessibility + polish)
- Warm-neutral palette (`stone-*` family) instead of cool grays for both light + dark

## Implementation phases

Order chosen so each phase builds on the previous, and we can stop early if needed.

| Phase | What | Files |
|---|---|---|
| 1 | Refined design tokens + typography scale + motion tokens | `R/ui_tokens.R` |
| 2 | New CSS: layout, bubbles, tool rows, code blocks, header, input, motion, scroll polish | `R/ui.R` |
| 3 | Refined render helpers: no-bubble assistant, minimal tool row, code block shell, system notice | `R/ui_render.R` |
| 4 | Header consolidation: model pill dropdown combining provider+model, icon toggles, kebab menu | `R/addin_chat.R` |
| 5 | Welcome rewrite: logo mark, setup cards, starter prompt rows | `R/ui_render.R` |
| 6 | Input embedding: Send inside card, focus glow, hint animation | `R/addin_chat.R`, `R/ui.R` |
| 7 | Motion: fade-in, accordion, crossfade | JS in `R/ui_render.R::cmd_enter_js()` |
| 8 | Details polish: scroll shadow, scrollbar, selection, focus rings | `R/ui.R` |

## Palette (warm neutrals)

### Light
```
bg_chat       #fbfbfa  (warm off-white)
bg_surface    #ffffff
bg_muted      #f5f5f4
bg_code       #0c0a09  (true warm charcoal)
border        #e7e5e4
border_subtle #f5f5f4
text          #0c0a09
text_muted    #57534e
text_subtle   #a8a29e
accent        #3b82f6
accent_bg     #eff6ff
success       #10b981  (run button, success dots)
warning       #f59e0b  (install toggle on, running dot)
danger        #ef4444
tool_read     #3b82f6  (read-only tool icon)
tool_write    #8b5cf6  (write tool icon)
tool_git      #059669
tool_web      #f59e0b
```

### Dark
```
bg_chat       #0c0a09
bg_surface    #1c1917
bg_muted      #292524
bg_code       #09090b
border        #292524
border_subtle #1c1917
text          #fafaf9
text_muted    #a8a29e
text_subtle   #78716c
accent        #60a5fa
accent_bg     #1e3a8a33
(others mirror with 'dark-friendly' lightness adjustments)
```

## Typography scale

| Token | Size | Use |
|---|---|---|
| xs | 11px | timestamps, token counts, ghost hints |
| sm | 12px | UI labels, tool names, status pills |
| base | 14px | body text, assistant responses |
| md | 15px | emphasized body |
| lg | 17px | section headings (H2/H3 in markdown) |
| xl | 20px | welcome heading |
| xxl | 28px | logo mark |

## Motion curves

| Token | Value | Use |
|---|---|---|
| fast | 120ms cubic-bezier(0.4, 0, 0.2, 1) | hover states |
| normal | 200ms cubic-bezier(0.4, 0, 0.2, 1) | transitions |
| slow | 320ms cubic-bezier(0.4, 0, 0.2, 1) | large reveals |
| bounce | 400ms cubic-bezier(0.34, 1.56, 0.64, 1) | delightful micro-interactions (rare) |

## Before / after

### Before (v1.1.0)
- Two-row header (title bar + controls bar, ~68px total)
- Assistant messages in white bubbles with "● sparx" label
- Tool cards are full-width purple-bordered cards
- Code blocks have separate header/footer rows with Insert/Run/Copy
- Bright white chat bg
- Cool-blue code bg
- Flat motion (jump cuts)

### After (v1.2.0)
- One-row header (~40px)
- Assistant messages as clean prose, no bubble
- Tool rows with left-chevron, colored icon, dots, expand-in-place
- Code blocks: rounded 8px, warm-black bg, hover-revealed copy, single action row
- Warm off-white chat bg (stone-50)
- Warm-black code bg matching theme
- Fade-in + accordion + crossfade motion throughout

## Success criteria

A user looking at sparx v1.2.0 next to Claude.ai or Cursor should feel they're looking at products of the same quality tier.

Every element should look intentional, nothing should look like a default Shiny control.

## Non-goals

- No React. No tauri. Keep Shiny gadget.
- No new runtime deps.
- No feature changes (agent behavior identical).
- No behavior changes to existing commands / toggles.
