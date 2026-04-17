#' Chat CSS — premium redesign (v1.2.0)
#'
#' References CSS variables emitted by tokens_to_css_variables().
#' Structure:
#'   1. Reset + root
#'   2. Layout (controls, thread, input)
#'   3. Assistant messages (no-bubble prose style)
#'   4. User messages (right-aligned pill)
#'   5. Tool rows (minimal horizontal with chevron + status dot)
#'   6. Code blocks (premium, hover-revealed copy)
#'   7. Diff view
#'   8. Image preview
#'   9. Todo list card
#'   10. System notice (compaction, etc.)
#'   11. Welcome / empty state (big logo mark + starters)
#'   12. Markdown prose
#'   13. Input (embedded send button)
#'   14. Slash-command menu
#'   15. Motion animations
#'   16. Scrollbar + selection
#' @keywords internal
chat_css <- function() {
  paste(
    tokens_to_css_variables(),
    "

/* ═══════════════════════════════════════════════════════════════════
   RESET + ROOT
   ═══════════════════════════════════════════════════════════════════ */

.sparx-container * { box-sizing: border-box; }

.sparx-container {
  display: flex;
  flex-direction: column;
  height: 100%;
  font-family: var(--sparx-font-sans, -apple-system, sans-serif);
  font-size: 14px;
  font-feature-settings: 'cv02', 'cv03', 'cv04', 'cv11';
  color: var(--sparx-color-text);
  background: var(--sparx-color-bg-chat);
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  letter-spacing: -0.005em;
}

/* ═══════════════════════════════════════════════════════════════════
   HEADER — single row, logo + model pill + icon toggles + kebab
   ═══════════════════════════════════════════════════════════════════ */

.sparx-controls {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 12px;
  border-bottom: 1px solid var(--sparx-color-border-subtle);
  background: var(--sparx-color-bg-surface);
  min-height: 40px;
  font-size: 12px;
  position: relative;
  z-index: 10;
  transition: box-shadow 200ms ease;
}
.sparx-controls.scrolled {
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.04);
}

.sparx-logo {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  font-weight: 600;
  font-size: 13px;
  color: var(--sparx-color-text);
  letter-spacing: -0.01em;
  flex-shrink: 0;
  user-select: none;
}
.sparx-logo-mark {
  color: var(--sparx-color-accent);
  font-weight: 700;
  font-size: 14px;
  display: inline-block;
  transform: translateY(-0.5px);
}

/* Model pill — clickable */
.sparx-model-pill {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 3px 9px;
  background: var(--sparx-color-bg-muted);
  border: 1px solid var(--sparx-color-border);
  border-radius: 9999px;
  font-size: 11px;
  font-weight: 500;
  color: var(--sparx-color-text);
  cursor: pointer;
  transition: all 120ms cubic-bezier(0.4, 0, 0.2, 1);
  flex-shrink: 0;
  user-select: none;
}
.sparx-model-pill:hover {
  background: var(--sparx-color-accent-bg);
  border-color: var(--sparx-color-accent-border);
  color: var(--sparx-color-accent);
}
.sparx-model-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--sparx-color-success);
  flex-shrink: 0;
}

/* Provider select — reuse model pill styling */
.sparx-controls .form-group {
  margin: 0 !important;
  display: inline-block;
  flex-shrink: 0;
}
.sparx-controls select.form-control {
  height: 24px !important;
  padding: 0 22px 0 9px !important;
  font-size: 11px !important;
  font-weight: 500 !important;
  line-height: 1.3 !important;
  background-color: var(--sparx-color-bg-muted) !important;
  color: var(--sparx-color-text) !important;
  border: 1px solid var(--sparx-color-border) !important;
  border-radius: 9999px !important;
  min-width: 150px !important;
  cursor: pointer;
  transition: all 120ms cubic-bezier(0.4, 0, 0.2, 1);
}
.sparx-controls select.form-control:hover {
  background-color: var(--sparx-color-accent-bg) !important;
  border-color: var(--sparx-color-accent-border) !important;
}
.sparx-controls select.form-control:focus {
  outline: none !important;
  box-shadow: var(--sparx-shadow-focus, 0 0 0 3px rgba(59, 130, 246, 0.18)) !important;
}

/* Icon toggles — tiny colored pills, color IS the state */
.sparx-toggle {
  padding: 2px 8px !important;
  font-size: 10px !important;
  font-weight: 600 !important;
  letter-spacing: 0.02em;
  line-height: 1.4 !important;
  background: transparent !important;
  color: var(--sparx-color-text-subtle) !important;
  border: 1px solid var(--sparx-color-border) !important;
  border-radius: 4px !important;
  height: 22px !important;
  margin: 0 !important;
  white-space: nowrap;
  flex-shrink: 0;
  transition: all 120ms cubic-bezier(0.4, 0, 0.2, 1);
  text-transform: uppercase;
}
.sparx-toggle:hover {
  background: var(--sparx-color-bg-muted) !important;
  color: var(--sparx-color-text) !important;
}
.sparx-toggle.sparx-toggle-on { font-weight: 700 !important; }
.sparx-toggle.sparx-toggle-on.sparx-toggle-plan {
  background: var(--sparx-color-accent-bg) !important;
  color: var(--sparx-color-accent) !important;
  border-color: var(--sparx-color-accent-border) !important;
}
.sparx-toggle.sparx-toggle-on.sparx-toggle-live {
  background: var(--sparx-color-success-bg) !important;
  color: var(--sparx-color-success-text) !important;
  border-color: var(--sparx-color-success) !important;
}
.sparx-toggle.sparx-toggle-on.sparx-toggle-install {
  background: var(--sparx-color-warning-bg) !important;
  color: var(--sparx-color-warning-text) !important;
  border-color: var(--sparx-color-warning) !important;
}
.sparx-toggle.sparx-toggle-on.sparx-toggle-git {
  background: var(--sparx-color-tool-bg) !important;
  color: var(--sparx-color-tool) !important;
  border-color: var(--sparx-color-tool-border) !important;
}

/* Token usage — micro-type at far right */
.sparx-usage {
  margin-left: auto;
  color: var(--sparx-color-text-subtle);
  font-family: var(--sparx-font-mono);
  font-size: 10px;
  font-variant-numeric: tabular-nums;
  flex-shrink: 0;
  white-space: nowrap;
  opacity: 0.7;
  transition: opacity 200ms;
}
.sparx-usage:hover { opacity: 1; }

.sparx-separator {
  color: var(--sparx-color-border);
  margin: 0 2px;
  flex-shrink: 0;
  user-select: none;
}

/* ═══════════════════════════════════════════════════════════════════
   THREAD
   ═══════════════════════════════════════════════════════════════════ */

.sparx-thread {
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
  padding: 18px 20px 24px 20px;
  background: var(--sparx-color-bg-chat);
  scroll-behavior: smooth;
}

/* ═══════════════════════════════════════════════════════════════════
   WELCOME / EMPTY STATE
   ═══════════════════════════════════════════════════════════════════ */

.sparx-welcome {
  padding: 24px 8px 12px 8px;
  color: var(--sparx-color-text-muted);
  animation: sparx-fade-in-up 400ms cubic-bezier(0.4, 0, 0.2, 1);
}

.sparx-welcome-hero {
  text-align: center;
  margin-bottom: 20px;
}
.sparx-welcome-logo {
  display: block;
  font-size: 32px;
  color: var(--sparx-color-accent);
  line-height: 1;
  margin-bottom: 6px;
  font-weight: 700;
  letter-spacing: -0.02em;
}
.sparx-welcome-name {
  font-size: 20px;
  font-weight: 700;
  color: var(--sparx-color-text);
  letter-spacing: -0.02em;
  margin-bottom: 2px;
}
.sparx-welcome-tagline {
  font-size: 12px;
  color: var(--sparx-color-text-muted);
  font-weight: 400;
  letter-spacing: 0;
}

.sparx-welcome-intro {
  margin: 18px 0 12px 0;
  color: var(--sparx-color-text);
  font-size: 14px;
  line-height: 1.55;
}

.sparx-welcome h3 {
  color: var(--sparx-color-text);
  margin: 0 0 10px 0;
  font-size: 14px;
  font-weight: 600;
}

/* Setup cards (for no-key state) */
.sparx-setup-card {
  background: var(--sparx-color-bg-surface);
  border: 1px solid var(--sparx-color-border);
  border-radius: 9px;
  padding: 12px 14px;
  margin: 8px 0;
  box-shadow: var(--sparx-shadow-xs, 0 1px 2px rgba(0,0,0,0.03));
}
.sparx-setup-card h4 {
  margin: 0 0 4px 0;
  font-size: 13px;
  font-weight: 600;
  color: var(--sparx-color-text);
}
.sparx-setup-card p {
  margin: 0 0 8px 0;
  font-size: 12px;
  color: var(--sparx-color-text-muted);
  line-height: 1.5;
}
.sparx-setup-card pre {
  margin: 0 !important;
  padding: 7px 10px !important;
  background: var(--sparx-color-bg-code) !important;
  color: var(--sparx-color-bg-code-text) !important;
  border-radius: 5px;
  font-size: 11px;
  font-family: var(--sparx-font-mono);
  line-height: 1.5;
}

/* Starter prompts — clean Raycast-style rows */
.sparx-starter {
  display: block;
  width: 100%;
  text-align: left;
  padding: 9px 12px 9px 10px;
  margin-bottom: 4px;
  background: transparent;
  border: 1px solid transparent;
  border-radius: 6px;
  font-size: 13px;
  color: var(--sparx-color-text);
  cursor: pointer;
  transition: all 120ms cubic-bezier(0.4, 0, 0.2, 1);
  font-family: inherit;
  line-height: 1.45;
}
.sparx-starter:hover {
  background: var(--sparx-color-bg-surface);
  border-color: var(--sparx-color-border);
  transform: translateX(1px);
}
.sparx-starter::before {
  content: '\\2192';
  color: var(--sparx-color-text-subtle);
  margin-right: 8px;
  font-weight: 400;
  transition: color 120ms;
}
.sparx-starter:hover::before { color: var(--sparx-color-accent); }

.sparx-privacy-note {
  margin-top: 20px;
  padding-top: 14px;
  border-top: 1px solid var(--sparx-color-border-subtle);
  font-size: 11px;
  line-height: 1.55;
  color: var(--sparx-color-text-subtle);
}

/* ═══════════════════════════════════════════════════════════════════
   USER MESSAGE — compact right-aligned pill
   ═══════════════════════════════════════════════════════════════════ */

.sparx-user-wrap {
  display: flex;
  justify-content: flex-end;
  margin-bottom: 12px;
  animation: sparx-fade-in-up 180ms cubic-bezier(0.4, 0, 0.2, 1);
}
.sparx-user {
  max-width: 85%;
  padding: 8px 12px;
  background: var(--sparx-color-user-bg);
  color: var(--sparx-color-user-text);
  border-radius: 12px;
  border-bottom-right-radius: 4px;
  font-size: 13px;
  line-height: 1.5;
  word-wrap: break-word;
  box-shadow: 0 1px 2px rgba(59, 130, 246, 0.15);
  letter-spacing: -0.005em;
}

/* ═══════════════════════════════════════════════════════════════════
   ASSISTANT — no bubble, just clean prose (Claude.ai style)
   ═══════════════════════════════════════════════════════════════════ */

.sparx-assistant {
  margin-bottom: 14px;
  padding: 4px 0;
  color: var(--sparx-color-text);
  line-height: 1.65;
  font-size: 14px;
  animation: sparx-fade-in-up 180ms cubic-bezier(0.4, 0, 0.2, 1);
}

/* Streaming caret */
.sparx-streaming-cursor {
  display: inline-block;
  width: 8px;
  height: 15px;
  background: var(--sparx-color-accent);
  margin-left: 2px;
  border-radius: 1px;
  animation: sparx-blink 1s steps(1) infinite;
  vertical-align: middle;
  transform: translateY(-1px);
}

/* ═══════════════════════════════════════════════════════════════════
   MARKDOWN — generous prose, clear hierarchy
   ═══════════════════════════════════════════════════════════════════ */

.sparx-markdown h1,
.sparx-markdown h2,
.sparx-markdown h3,
.sparx-markdown h4,
.sparx-markdown h5,
.sparx-markdown h6 {
  color: var(--sparx-color-text);
  margin: 16px 0 8px 0;
  font-weight: 600;
  line-height: 1.35;
  letter-spacing: -0.01em;
}
.sparx-markdown h1 { font-size: 18px; }
.sparx-markdown h2 { font-size: 16px; }
.sparx-markdown h3 { font-size: 15px; }
.sparx-markdown h4,
.sparx-markdown h5,
.sparx-markdown h6 { font-size: 14px; }

.sparx-markdown p {
  margin: 0 0 10px 0;
}
.sparx-markdown p:last-child { margin-bottom: 0; }

.sparx-markdown ul,
.sparx-markdown ol {
  margin: 6px 0 10px 0;
  padding-left: 22px;
}
.sparx-markdown li {
  margin: 3px 0;
  line-height: 1.6;
}
.sparx-markdown li > p { margin: 0; }

.sparx-markdown blockquote {
  margin: 10px 0;
  padding: 4px 14px;
  border-left: 3px solid var(--sparx-color-accent-border);
  color: var(--sparx-color-text-muted);
  background: var(--sparx-color-accent-bg);
  border-radius: 0 6px 6px 0;
  font-style: italic;
}

.sparx-markdown a {
  color: var(--sparx-color-accent);
  text-decoration: none;
  border-bottom: 1px solid transparent;
  transition: border-color 120ms;
}
.sparx-markdown a:hover {
  border-bottom-color: var(--sparx-color-accent);
}

.sparx-markdown table {
  border-collapse: collapse;
  margin: 10px 0;
  font-size: 12px;
  max-width: 100%;
  overflow-x: auto;
  display: block;
  white-space: nowrap;
  border-radius: 6px;
  border: 1px solid var(--sparx-color-border);
}
.sparx-markdown th,
.sparx-markdown td {
  border-right: 1px solid var(--sparx-color-border-subtle);
  border-bottom: 1px solid var(--sparx-color-border-subtle);
  padding: 6px 10px;
  text-align: left;
}
.sparx-markdown th:last-child,
.sparx-markdown td:last-child { border-right: none; }
.sparx-markdown tr:last-child td { border-bottom: none; }
.sparx-markdown th {
  background: var(--sparx-color-bg-muted);
  font-weight: 600;
  color: var(--sparx-color-text);
}

.sparx-markdown code:not(pre code) {
  background: var(--sparx-color-bg-muted);
  padding: 1px 5px;
  border-radius: 4px;
  font-size: 12.5px;
  font-family: var(--sparx-font-mono);
  color: var(--sparx-color-accent);
  border: 1px solid var(--sparx-color-border-subtle);
  font-weight: 500;
}

.sparx-markdown hr {
  border: none;
  border-top: 1px solid var(--sparx-color-border);
  margin: 14px 0;
}

/* ═══════════════════════════════════════════════════════════════════
   CODE BLOCKS — premium dark block with hover-revealed copy
   ═══════════════════════════════════════════════════════════════════ */

.sparx-codeblock {
  position: relative;
  margin: 12px 0;
  border-radius: 8px;
  overflow: hidden;
  background: var(--sparx-color-bg-code);
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.08);
}
.sparx-codeblock-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 6px 12px;
  background: rgba(255, 255, 255, 0.02);
  border-bottom: 1px solid rgba(255, 255, 255, 0.05);
  font-size: 10.5px;
  color: #a8a29e;
  font-family: var(--sparx-font-mono);
  min-height: 26px;
}
.sparx-codeblock-lang {
  font-weight: 600;
  text-transform: lowercase;
  letter-spacing: 0.02em;
  color: #d6d3d1;
}
.sparx-codeblock-meta {
  color: #78716c;
  font-size: 10px;
  margin-left: 8px;
}
.sparx-codeblock-copy {
  background: transparent;
  border: 1px solid transparent;
  color: #a8a29e;
  cursor: pointer;
  font-size: 10.5px;
  padding: 3px 8px;
  border-radius: 4px;
  transition: all 120ms;
  opacity: 0.6;
  font-weight: 500;
}
.sparx-codeblock:hover .sparx-codeblock-copy { opacity: 1; }
.sparx-codeblock-copy:hover {
  background: rgba(255, 255, 255, 0.08);
  color: #f5f5f4;
  border-color: rgba(255, 255, 255, 0.12);
}
.sparx-codeblock pre {
  background: var(--sparx-color-bg-code) !important;
  color: var(--sparx-color-bg-code-text) !important;
  padding: 11px 14px !important;
  margin: 0 !important;
  overflow-x: auto;
  font-size: 12.5px;
  font-family: var(--sparx-font-mono);
  line-height: 1.55;
  border: none !important;
  font-feature-settings: 'liga' 1;
}
.sparx-codeblock pre code {
  background: transparent !important;
  padding: 0 !important;
  border: none !important;
  color: inherit !important;
  font-family: inherit !important;
  font-size: inherit !important;
  font-weight: normal !important;
}
.sparx-code-actions {
  display: flex;
  gap: 4px;
  padding: 7px 10px;
  background: rgba(255, 255, 255, 0.02);
  border-top: 1px solid rgba(255, 255, 255, 0.05);
}
.sparx-code-actions button {
  background: transparent;
  border: 1px solid rgba(255, 255, 255, 0.1);
  color: #d6d3d1;
  padding: 4px 12px;
  border-radius: 5px;
  font-size: 11px;
  font-weight: 500;
  cursor: pointer;
  transition: all 120ms;
  font-family: inherit;
  letter-spacing: -0.005em;
}
.sparx-code-actions button:hover {
  background: rgba(255, 255, 255, 0.07);
  border-color: rgba(255, 255, 255, 0.18);
  color: #fafaf9;
}
.sparx-code-actions button.sparx-run {
  background: var(--sparx-color-success);
  border-color: var(--sparx-color-success);
  color: white;
  font-weight: 600;
}
.sparx-code-actions button.sparx-run:hover {
  background: #0ea16f;
  border-color: #0ea16f;
}

/* ═══════════════════════════════════════════════════════════════════
   TOOL ROWS — minimal horizontal, clickable to expand
   ═══════════════════════════════════════════════════════════════════ */

.sparx-tool {
  margin: 3px 0;
  background: transparent;
  border: 1px solid transparent;
  border-radius: 7px;
  overflow: hidden;
  font-size: 12px;
  transition: background 120ms;
  animation: sparx-fade-in-up 180ms cubic-bezier(0.4, 0, 0.2, 1);
}
.sparx-tool:hover {
  background: var(--sparx-color-bg-muted);
}

.sparx-tool-summary {
  display: grid;
  grid-template-columns: 12px 16px auto 1fr auto auto;
  gap: 8px;
  align-items: center;
  padding: 5px 10px;
  cursor: pointer;
  user-select: none;
  line-height: 1.3;
}
.sparx-tool-chevron {
  color: var(--sparx-color-text-subtle);
  font-size: 10px;
  transition: transform 200ms cubic-bezier(0.4, 0, 0.2, 1);
  transform: rotate(0deg);
  transform-origin: center;
  display: inline-block;
  line-height: 1;
}
.sparx-tool.expanded .sparx-tool-chevron { transform: rotate(90deg); }

.sparx-tool-icon {
  font-family: var(--sparx-font-mono);
  font-weight: 700;
  color: var(--sparx-color-tool-read);
  flex-shrink: 0;
  text-align: center;
  font-size: 10.5px;
  line-height: 1;
}
.sparx-tool.tool-cat-read  .sparx-tool-icon { color: var(--sparx-color-tool-read); }
.sparx-tool.tool-cat-write .sparx-tool-icon { color: var(--sparx-color-tool-write); }
.sparx-tool.tool-cat-run   .sparx-tool-icon { color: var(--sparx-color-tool-run); }
.sparx-tool.tool-cat-git   .sparx-tool-icon { color: var(--sparx-color-tool-git); }
.sparx-tool.tool-cat-web   .sparx-tool-icon { color: var(--sparx-color-tool-web); }

.sparx-tool-name {
  color: var(--sparx-color-text);
  font-weight: 600;
  font-size: 11.5px;
  flex-shrink: 0;
  letter-spacing: -0.005em;
}

.sparx-tool-input {
  color: var(--sparx-color-text-muted);
  font-family: var(--sparx-font-mono);
  font-size: 11px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  min-width: 0;
}

.sparx-tool-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: var(--sparx-color-success);
  flex-shrink: 0;
}
.sparx-tool.running .sparx-tool-dot {
  background: var(--sparx-color-warning);
  animation: sparx-pulse 1.2s ease-in-out infinite;
}
.sparx-tool.error .sparx-tool-dot { background: var(--sparx-color-danger); }

.sparx-tool-status {
  color: var(--sparx-color-text-subtle);
  font-size: 10.5px;
  flex-shrink: 0;
  white-space: nowrap;
  font-family: var(--sparx-font-mono);
  font-variant-numeric: tabular-nums;
}
.sparx-tool.error .sparx-tool-status { color: var(--sparx-color-danger); }

.sparx-tool-details {
  display: grid;
  grid-template-rows: 0fr;
  transition: grid-template-rows 250ms cubic-bezier(0.4, 0, 0.2, 1);
}
.sparx-tool.expanded .sparx-tool-details { grid-template-rows: 1fr; }
.sparx-tool-details-inner {
  overflow: hidden;
  min-height: 0;
}
.sparx-tool.expanded .sparx-tool-details-inner {
  overflow: auto;
  max-height: 320px;
}
.sparx-tool-details-body {
  padding: 6px 12px 10px 38px;
  background: var(--sparx-color-bg-surface);
  border-top: 1px solid var(--sparx-color-border-subtle);
}
.sparx-tool-details-body pre {
  margin: 0;
  font-family: var(--sparx-font-mono);
  font-size: 11px;
  color: var(--sparx-color-text);
  white-space: pre-wrap;
  word-break: break-word;
  line-height: 1.5;
  background: transparent;
  border: none;
  padding: 0;
}

/* ═══════════════════════════════════════════════════════════════════
   DIFF VIEW
   ═══════════════════════════════════════════════════════════════════ */

.sparx-diff {
  margin-top: 8px;
  padding: 8px 10px;
  background: var(--sparx-color-bg-code);
  border-radius: 6px;
  font-family: var(--sparx-font-mono);
  font-size: 11.5px;
  max-height: 240px;
  overflow: auto;
  white-space: pre;
  line-height: 1.55;
}
.sparx-diff-line-add {
  color: #86efac;
  background: rgba(16, 185, 129, 0.12);
  display: block;
  padding: 0 4px;
  margin: 0 -10px;
  padding-left: 14px;
}
.sparx-diff-line-del {
  color: #fca5a5;
  background: rgba(239, 68, 68, 0.12);
  display: block;
  padding: 0 4px;
  margin: 0 -10px;
  padding-left: 14px;
}

/* ═══════════════════════════════════════════════════════════════════
   IMAGE PREVIEW
   ═══════════════════════════════════════════════════════════════════ */

.sparx-image-preview { margin-top: 8px; }
.sparx-image-preview img {
  max-width: 100%;
  max-height: 300px;
  border-radius: 8px;
  border: 1px solid var(--sparx-color-border);
  box-shadow: var(--sparx-shadow-sm);
}

/* ═══════════════════════════════════════════════════════════════════
   TODO LIST (multi-step tracker)
   ═══════════════════════════════════════════════════════════════════ */

.sparx-todos {
  margin: 12px 0;
  padding: 11px 14px;
  background: var(--sparx-color-warning-bg);
  border-left: 3px solid var(--sparx-color-warning);
  border-radius: 0 6px 6px 0;
}
.sparx-todos-header {
  font-weight: 600;
  font-size: 10px;
  color: var(--sparx-color-warning-text);
  margin-bottom: 7px;
  text-transform: uppercase;
  letter-spacing: 0.06em;
}
.sparx-todo-item {
  font-size: 12.5px;
  padding: 2px 0;
  display: flex;
  gap: 7px;
  align-items: flex-start;
  color: var(--sparx-color-text);
  line-height: 1.55;
}
.sparx-todo-item.done {
  color: var(--sparx-color-text-subtle);
  text-decoration: line-through;
}
.sparx-todo-item.active { font-weight: 600; }
.sparx-todo-marker {
  font-family: var(--sparx-font-mono);
  flex-shrink: 0;
  width: 16px;
  opacity: 0.7;
}

/* ═══════════════════════════════════════════════════════════════════
   SYSTEM NOTICE (compaction indicator, etc.)
   ═══════════════════════════════════════════════════════════════════ */

.sparx-system-notice {
  margin: 14px 0;
  padding: 4px 0;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  color: var(--sparx-color-text-subtle);
  font-size: 10.5px;
  letter-spacing: 0.02em;
  position: relative;
}
.sparx-system-notice::before,
.sparx-system-notice::after {
  content: '';
  flex: 1;
  height: 1px;
  background: var(--sparx-color-border-subtle);
}
.sparx-system-notice-icon { opacity: 0.6; }

/* ═══════════════════════════════════════════════════════════════════
   INPUT AREA — embedded Send, soft focus ring
   ═══════════════════════════════════════════════════════════════════ */

.sparx-input-area {
  padding: 10px 12px 12px 12px;
  background: var(--sparx-color-bg-surface);
  border-top: 1px solid var(--sparx-color-border-subtle);
}
.sparx-input-wrapper {
  position: relative;
  background: var(--sparx-color-bg-input);
  border: 1px solid var(--sparx-color-border);
  border-radius: 10px;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.02);
  transition: all 200ms cubic-bezier(0.4, 0, 0.2, 1);
  display: flex;
  flex-direction: column;
}
.sparx-input-wrapper:focus-within {
  border-color: var(--sparx-color-accent);
  box-shadow: 0 0 0 3px var(--sparx-color-accent-bg);
}

.sparx-input-area textarea.form-control {
  width: 100%;
  min-height: 38px;
  max-height: 160px;
  padding: 10px 12px !important;
  font-size: 13.5px !important;
  line-height: 1.5 !important;
  background: transparent !important;
  color: var(--sparx-color-text) !important;
  border: none !important;
  border-radius: 10px !important;
  resize: none !important;
  overflow-y: auto;
  outline: none !important;
  box-shadow: none !important;
  font-family: inherit;
}
.sparx-input-area textarea.form-control::placeholder {
  color: var(--sparx-color-text-subtle);
}

.sparx-input-actions-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 4px 10px 8px 12px;
}
.sparx-hint {
  font-size: 10.5px;
  color: var(--sparx-color-text-subtle);
  letter-spacing: -0.005em;
}
.sparx-send-group {
  display: flex;
  gap: 4px;
  align-items: center;
}
.sparx-send-group .btn {
  height: 26px !important;
  padding: 0 12px !important;
  font-size: 11.5px !important;
  font-weight: 600 !important;
  border-radius: 6px !important;
  letter-spacing: -0.005em;
  line-height: 1 !important;
  transition: all 120ms cubic-bezier(0.4, 0, 0.2, 1);
}
.sparx-send-group .btn-primary {
  background: var(--sparx-color-accent) !important;
  border-color: var(--sparx-color-accent) !important;
  color: white !important;
}
.sparx-send-group .btn-primary:hover:not(:disabled) {
  background: var(--sparx-color-accent-hover) !important;
  border-color: var(--sparx-color-accent-hover) !important;
}
.sparx-send-group .btn-danger {
  background: var(--sparx-color-danger) !important;
  border-color: var(--sparx-color-danger) !important;
  color: white !important;
}

.sparx-stop { display: none !important; }
.sparx-streaming .sparx-stop { display: inline-block !important; }
.sparx-streaming #send { display: none !important; }

/* ═══════════════════════════════════════════════════════════════════
   SLASH-COMMAND MENU
   ═══════════════════════════════════════════════════════════════════ */

.sparx-slash-menu {
  position: absolute;
  bottom: 100%;
  left: 0;
  margin-bottom: 8px;
  background: var(--sparx-color-bg-surface);
  border: 1px solid var(--sparx-color-border);
  border-radius: 8px;
  box-shadow: 0 12px 24px rgba(0, 0, 0, 0.08), 0 2px 4px rgba(0, 0, 0, 0.04);
  padding: 4px;
  min-width: 280px;
  z-index: 100;
  display: none;
  max-height: 240px;
  overflow-y: auto;
}
.sparx-slash-menu.active {
  display: block;
  animation: sparx-fade-in-up 120ms cubic-bezier(0.4, 0, 0.2, 1);
}
.sparx-slash-item {
  display: grid;
  grid-template-columns: auto 1fr;
  gap: 10px;
  align-items: center;
  padding: 6px 10px;
  border-radius: 5px;
  cursor: pointer;
  font-size: 12px;
  transition: background 80ms;
}
.sparx-slash-item:hover,
.sparx-slash-item.selected {
  background: var(--sparx-color-accent-bg);
}
.sparx-slash-cmd {
  font-family: var(--sparx-font-mono);
  font-weight: 600;
  color: var(--sparx-color-accent);
  font-size: 11.5px;
}
.sparx-slash-desc {
  color: var(--sparx-color-text-muted);
  font-size: 11.5px;
}

/* ═══════════════════════════════════════════════════════════════════
   MOTION
   ═══════════════════════════════════════════════════════════════════ */

@keyframes sparx-fade-in-up {
  from { opacity: 0; transform: translateY(4px); }
  to   { opacity: 1; transform: translateY(0); }
}
@keyframes sparx-blink {
  0%, 50%, 100% { opacity: 1; }
  51%, 99%      { opacity: 0.2; }
}
@keyframes sparx-pulse {
  0%, 100% { opacity: 1; transform: scale(1); }
  50%      { opacity: 0.55; transform: scale(1.15); }
}
@keyframes sparx-spin {
  from { transform: rotate(0deg); }
  to   { transform: rotate(360deg); }
}
@keyframes sparx-point-highlight {
  0%   { box-shadow: 0 0 0 0 rgba(139, 92, 246, 0.5); }
  50%  { box-shadow: 0 0 0 6px rgba(139, 92, 246, 0.2); }
  100% { box-shadow: 0 0 0 0 rgba(139, 92, 246, 0); }
}
.companion-point-highlight {
  animation: sparx-point-highlight 1.5s ease-out;
}

/* ═══════════════════════════════════════════════════════════════════
   SCROLLBAR + SELECTION
   ═══════════════════════════════════════════════════════════════════ */

.sparx-thread::-webkit-scrollbar,
.sparx-tool-details-inner::-webkit-scrollbar,
.sparx-slash-menu::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}
.sparx-thread::-webkit-scrollbar-track,
.sparx-tool-details-inner::-webkit-scrollbar-track,
.sparx-slash-menu::-webkit-scrollbar-track { background: transparent; }
.sparx-thread::-webkit-scrollbar-thumb,
.sparx-tool-details-inner::-webkit-scrollbar-thumb,
.sparx-slash-menu::-webkit-scrollbar-thumb {
  background: var(--sparx-color-border-strong);
  border-radius: 4px;
  border: 2px solid var(--sparx-color-bg-chat);
}
.sparx-thread::-webkit-scrollbar-thumb:hover,
.sparx-tool-details-inner::-webkit-scrollbar-thumb:hover,
.sparx-slash-menu::-webkit-scrollbar-thumb:hover {
  background: var(--sparx-color-text-subtle);
}

.sparx-container ::selection {
  background: var(--sparx-color-accent-bg);
  color: var(--sparx-color-accent-hover);
}
  ",
    sep = "\n"
  )
}
