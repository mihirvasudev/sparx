#' UI helpers for the sparx chat gadget
#'
#' Design tokens live in ui_tokens.R. This file uses CSS variables set
#' on :root (light) and [data-theme="dark"] (dark) so theming works via
#' a single class-swap, without regenerating CSS at runtime.

#' Chat CSS — uses CSS variables defined via tokens_to_css_variables()
#' @keywords internal
chat_css <- function() {
  paste(
    tokens_to_css_variables(),
    "
  /* ── Root container ──────────────────────────────── */
  .sparx-container {
    display: flex;
    flex-direction: column;
    height: 100%;
    font-family: var(--sparx-font-sans, -apple-system, system-ui);
    font-size: 13px;
    color: var(--sparx-color-text);
    background: var(--sparx-color-bg-chat);
  }

  /* ── Thread area ─────────────────────────────────── */
  .sparx-thread {
    flex: 1;
    overflow-y: auto;
    overflow-x: hidden;
    padding: 14px 16px 20px 16px;
    background: var(--sparx-color-bg-chat);
    scroll-behavior: smooth;
  }

  /* ── Welcome / empty state ───────────────────────── */
  .sparx-welcome {
    padding: 20px 16px;
    color: var(--sparx-color-text-muted);
    font-size: 13px;
    line-height: 1.6;
  }
  .sparx-welcome h3 {
    color: var(--sparx-color-text);
    margin: 0 0 10px 0;
    font-size: 15px;
    font-weight: 600;
  }
  .sparx-welcome .sparx-welcome-intro {
    margin-bottom: 14px;
    color: var(--sparx-color-text-muted);
  }
  .sparx-starter {
    display: block;
    width: 100%;
    text-align: left;
    padding: 8px 12px;
    margin-bottom: 6px;
    background: var(--sparx-color-bg-surface);
    border: 1px solid var(--sparx-color-border);
    border-radius: 8px;
    font-size: 12px;
    color: var(--sparx-color-text);
    cursor: pointer;
    transition: all 120ms ease;
  }
  .sparx-starter:hover {
    background: var(--sparx-color-accent-bg);
    border-color: var(--sparx-color-accent-border);
    color: var(--sparx-color-accent);
    transform: translateY(-1px);
  }
  .sparx-starter::before {
    content: '\\2192  ';
    color: var(--sparx-color-text-subtle);
    margin-right: 4px;
  }
  .sparx-starter:hover::before { color: var(--sparx-color-accent); }

  /* ── Message bubbles ─────────────────────────────── */
  .sparx-bubble {
    margin-bottom: 10px;
    padding: 9px 13px;
    border-radius: 10px;
    max-width: 100%;
    word-wrap: break-word;
    line-height: 1.55;
    font-size: 13px;
  }
  .sparx-user {
    background: var(--sparx-color-user-bg);
    color: var(--sparx-color-user-text);
    margin-left: 15%;
    box-shadow: 0 1px 2px rgba(0,0,0,0.05);
    border-bottom-right-radius: 4px;
  }

  /* Assistant message — full-width text, no bubble border */
  .sparx-assistant {
    margin-right: 5%;
    margin-bottom: 14px;
    color: var(--sparx-color-text);
    line-height: 1.6;
    font-size: 13px;
  }
  .sparx-assistant .sparx-sender {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 10px;
    color: var(--sparx-color-text-subtle);
    margin-bottom: 6px;
    text-transform: uppercase;
    letter-spacing: 0.3px;
    font-weight: 600;
  }
  .sparx-assistant .sparx-sender-dot {
    width: 6px;
    height: 6px;
    background: var(--sparx-color-accent);
    border-radius: 50%;
  }

  /* ── Markdown elements inside assistant messages ─── */
  .sparx-markdown h1,
  .sparx-markdown h2,
  .sparx-markdown h3,
  .sparx-markdown h4,
  .sparx-markdown h5,
  .sparx-markdown h6 {
    color: var(--sparx-color-text);
    margin: 14px 0 6px 0;
    font-weight: 600;
    line-height: 1.3;
  }
  .sparx-markdown h1 { font-size: 17px; }
  .sparx-markdown h2 { font-size: 15px; }
  .sparx-markdown h3 { font-size: 14px; }
  .sparx-markdown h4,
  .sparx-markdown h5,
  .sparx-markdown h6 { font-size: 13px; }

  .sparx-markdown p {
    margin: 0 0 10px 0;
  }
  .sparx-markdown p:last-child {
    margin-bottom: 0;
  }
  .sparx-markdown ul,
  .sparx-markdown ol {
    margin: 4px 0 10px 0;
    padding-left: 22px;
  }
  .sparx-markdown li {
    margin: 2px 0;
  }
  .sparx-markdown blockquote {
    margin: 8px 0;
    padding: 2px 12px;
    border-left: 3px solid var(--sparx-color-accent-border);
    color: var(--sparx-color-text-muted);
    background: var(--sparx-color-bg-muted);
    border-radius: 0 4px 4px 0;
  }
  .sparx-markdown a {
    color: var(--sparx-color-accent);
    text-decoration: none;
  }
  .sparx-markdown a:hover {
    text-decoration: underline;
  }
  .sparx-markdown table {
    border-collapse: collapse;
    margin: 8px 0;
    font-size: 12px;
    max-width: 100%;
    overflow-x: auto;
    display: block;
  }
  .sparx-markdown th,
  .sparx-markdown td {
    border: 1px solid var(--sparx-color-border);
    padding: 4px 8px;
    text-align: left;
  }
  .sparx-markdown th {
    background: var(--sparx-color-bg-muted);
    font-weight: 600;
  }
  .sparx-markdown code:not(pre code) {
    background: var(--sparx-color-bg-muted);
    padding: 1px 5px;
    border-radius: 3px;
    font-size: 12px;
    font-family: var(--sparx-font-mono, monospace);
    color: var(--sparx-color-accent);
    border: 1px solid var(--sparx-color-border-subtle);
  }

  /* ── Code blocks (with Prism highlighting) ────────── */
  .sparx-codeblock {
    position: relative;
    margin: 10px 0;
    border-radius: 8px;
    overflow: hidden;
    background: var(--sparx-color-bg-code);
    border: 1px solid var(--sparx-color-border);
  }
  .sparx-codeblock-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 4px 10px;
    background: rgba(255,255,255,0.03);
    border-bottom: 1px solid rgba(255,255,255,0.08);
    font-size: 10px;
    color: #94a3b8;
    font-family: var(--sparx-font-mono);
  }
  .sparx-codeblock-lang {
    font-weight: 600;
    text-transform: lowercase;
    letter-spacing: 0.3px;
  }
  .sparx-codeblock-meta {
    color: #64748b;
    font-size: 9px;
  }
  .sparx-codeblock-copy {
    background: transparent;
    border: none;
    color: #94a3b8;
    cursor: pointer;
    font-size: 11px;
    padding: 2px 6px;
    border-radius: 3px;
    transition: all 120ms;
  }
  .sparx-codeblock-copy:hover {
    background: rgba(255,255,255,0.08);
    color: #e2e8f0;
  }
  .sparx-codeblock pre {
    background: var(--sparx-color-bg-code) !important;
    color: var(--sparx-color-bg-code-text) !important;
    padding: 10px 12px !important;
    margin: 0 !important;
    overflow-x: auto;
    font-size: 12px;
    font-family: var(--sparx-font-mono);
    line-height: 1.55;
    border: none !important;
  }
  .sparx-codeblock pre code {
    background: transparent !important;
    padding: 0 !important;
    border: none !important;
    color: inherit !important;
    font-family: inherit !important;
    font-size: inherit !important;
  }
  .sparx-code-actions {
    display: flex;
    gap: 4px;
    padding: 6px 10px;
    background: rgba(255,255,255,0.02);
    border-top: 1px solid rgba(255,255,255,0.06);
  }
  .sparx-code-actions button {
    background: transparent;
    border: 1px solid rgba(255,255,255,0.12);
    color: #cbd5e1;
    padding: 3px 10px;
    border-radius: 4px;
    font-size: 11px;
    cursor: pointer;
    font-weight: 500;
    transition: all 120ms;
  }
  .sparx-code-actions button:hover {
    background: rgba(255,255,255,0.08);
    border-color: rgba(255,255,255,0.2);
    color: #f3f4f6;
  }
  .sparx-code-actions button.sparx-run {
    background: var(--sparx-color-success);
    border-color: var(--sparx-color-success);
    color: white;
  }
  .sparx-code-actions button.sparx-run:hover {
    background: #059669;
    border-color: #059669;
  }

  /* ── Controls bar ────────────────────────────────── */
  .sparx-controls {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 5px 10px;
    border-bottom: 1px solid var(--sparx-color-border);
    background: var(--sparx-color-bg-surface);
    font-size: 10px;
    flex-wrap: nowrap;
    overflow: hidden;
    min-height: 30px;
  }
  .sparx-model-pill {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    padding: 3px 8px;
    background: var(--sparx-color-bg-muted);
    border: 1px solid var(--sparx-color-border);
    border-radius: 999px;
    font-size: 10px;
    color: var(--sparx-color-text);
    cursor: pointer;
    transition: all 120ms;
    flex-shrink: 0;
  }
  .sparx-model-pill:hover {
    background: var(--sparx-color-accent-bg);
    border-color: var(--sparx-color-accent-border);
  }
  .sparx-model-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: var(--sparx-color-success);
    flex-shrink: 0;
  }
  .sparx-controls .form-group {
    margin: 0 !important;
    display: inline-block;
    flex-shrink: 0;
  }
  .sparx-controls select.form-control {
    height: 22px !important;
    padding: 0 18px 0 6px !important;
    font-size: 10px !important;
    line-height: 1.3 !important;
    background-color: var(--sparx-color-bg-surface) !important;
    color: var(--sparx-color-text) !important;
    border-color: var(--sparx-color-border) !important;
    border-radius: 4px !important;
    min-width: 140px !important;
  }
  .sparx-usage {
    margin-left: auto;
    color: var(--sparx-color-text-subtle);
    font-family: var(--sparx-font-mono);
    font-size: 9px;
    flex-shrink: 0;
    white-space: nowrap;
  }
  .sparx-gear {
    background: transparent;
    border: none;
    color: var(--sparx-color-text-muted);
    cursor: pointer;
    font-size: 13px;
    padding: 2px 6px;
    border-radius: 4px;
    transition: all 120ms;
  }
  .sparx-gear:hover {
    background: var(--sparx-color-bg-muted);
    color: var(--sparx-color-text);
  }

  /* Toggle buttons (shown inside the gear menu) */
  .sparx-toggle {
    padding: 2px 8px !important;
    font-size: 10px !important;
    line-height: 1.3 !important;
    background: var(--sparx-color-bg-surface) !important;
    color: var(--sparx-color-text-muted) !important;
    border: 1px solid var(--sparx-color-border) !important;
    border-radius: 4px !important;
    height: 20px !important;
    margin: 0 !important;
    white-space: nowrap;
  }
  .sparx-toggle:hover {
    background: var(--sparx-color-accent-bg) !important;
    color: var(--sparx-color-accent) !important;
    border-color: var(--sparx-color-accent-border) !important;
  }
  .sparx-separator {
    color: var(--sparx-color-border);
    margin: 0 2px;
    flex-shrink: 0;
  }

  /* ── Tool cards (collapsible) ────────────────────── */
  .sparx-tool {
    margin: 6px 0;
    border: 1px solid var(--sparx-color-tool-border);
    background: var(--sparx-color-tool-bg);
    border-radius: 6px;
    overflow: hidden;
    font-size: 12px;
  }
  .sparx-tool-summary {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 10px;
    cursor: pointer;
    user-select: none;
    transition: background 120ms;
  }
  .sparx-tool-summary:hover {
    background: rgba(139, 92, 246, 0.08);
  }
  .sparx-tool-chevron {
    color: var(--sparx-color-tool);
    font-size: 9px;
    transition: transform 120ms;
    flex-shrink: 0;
    width: 10px;
  }
  .sparx-tool.expanded .sparx-tool-chevron {
    transform: rotate(90deg);
  }
  .sparx-tool-icon {
    font-family: var(--sparx-font-mono);
    font-size: 11px;
    color: var(--sparx-color-tool);
    flex-shrink: 0;
    width: 14px;
    text-align: center;
  }
  .sparx-tool-name {
    color: var(--sparx-color-tool);
    font-weight: 600;
    font-size: 11px;
    flex-shrink: 0;
  }
  .sparx-tool-input {
    color: var(--sparx-color-text-muted);
    font-family: var(--sparx-font-mono);
    font-size: 11px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    min-width: 0;
    flex: 1;
  }
  .sparx-tool-status {
    color: var(--sparx-color-text-muted);
    font-size: 10px;
    flex-shrink: 0;
    white-space: nowrap;
  }
  .sparx-tool-status.err { color: var(--sparx-color-danger); }
  .sparx-tool-status.ok { color: var(--sparx-color-success); }
  .sparx-tool-details {
    display: none;
    padding: 8px 10px;
    background: var(--sparx-color-bg-surface);
    border-top: 1px solid var(--sparx-color-tool-border);
    max-height: 300px;
    overflow: auto;
  }
  .sparx-tool.expanded .sparx-tool-details {
    display: block;
  }
  .sparx-tool-details pre {
    margin: 0;
    font-family: var(--sparx-font-mono);
    font-size: 11px;
    color: var(--sparx-color-text);
    white-space: pre-wrap;
    word-break: break-word;
  }
  .sparx-tool.running .sparx-tool-icon::after {
    content: '';
    display: inline-block;
    width: 8px;
    height: 8px;
    border: 1.5px solid var(--sparx-color-tool);
    border-top-color: transparent;
    border-radius: 50%;
    animation: sparx-spin 800ms linear infinite;
    margin-left: 2px;
  }
  @keyframes sparx-spin {
    to { transform: rotate(360deg); }
  }

  /* ── Diff view ───────────────────────────────────── */
  .sparx-diff {
    margin-top: 6px;
    padding: 6px 8px;
    background: var(--sparx-color-bg-surface);
    border: 1px solid var(--sparx-color-border);
    border-radius: 4px;
    font-family: var(--sparx-font-mono);
    font-size: 11px;
    max-height: 200px;
    overflow: auto;
    white-space: pre;
  }
  .sparx-diff-line-add {
    color: var(--sparx-color-success-text);
    background: var(--sparx-color-success-bg);
    display: block;
  }
  .sparx-diff-line-del {
    color: var(--sparx-color-danger-text);
    background: var(--sparx-color-danger-bg);
    display: block;
  }

  /* ── Image preview ───────────────────────────────── */
  .sparx-image-preview {
    margin-top: 6px;
  }
  .sparx-image-preview img {
    max-width: 100%;
    max-height: 280px;
    border-radius: 4px;
    border: 1px solid var(--sparx-color-border);
  }

  /* ── Todo list ───────────────────────────────────── */
  .sparx-todos {
    margin: 10px 0;
    padding: 10px 12px;
    background: var(--sparx-color-warning-bg);
    border-left: 3px solid var(--sparx-color-warning);
    border-radius: 4px;
  }
  .sparx-todos-header {
    font-weight: 600;
    font-size: 10px;
    color: var(--sparx-color-text-muted);
    margin-bottom: 6px;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
  .sparx-todo-item {
    font-size: 12px;
    padding: 2px 0;
    display: flex;
    gap: 6px;
    align-items: flex-start;
    color: var(--sparx-color-text);
  }
  .sparx-todo-item.done {
    color: var(--sparx-color-text-subtle);
    text-decoration: line-through;
  }
  .sparx-todo-item.active {
    font-weight: 600;
  }
  .sparx-todo-marker {
    font-family: monospace;
    flex-shrink: 0;
    width: 14px;
  }

  /* ── Input area ─────────────────────────────────── */
  .sparx-input-area {
    padding: 10px 12px;
    border-top: 1px solid var(--sparx-color-border);
    background: var(--sparx-color-bg-surface);
  }
  .sparx-input-wrapper {
    position: relative;
    display: flex;
    align-items: flex-end;
    gap: 8px;
  }
  .sparx-input-area textarea.form-control {
    flex: 1;
    min-height: 38px;
    max-height: 160px;
    padding: 8px 10px !important;
    font-size: 13px !important;
    line-height: 1.5 !important;
    background: var(--sparx-color-bg-input) !important;
    color: var(--sparx-color-text) !important;
    border: 1px solid var(--sparx-color-border) !important;
    border-radius: 6px !important;
    resize: none !important;
    overflow-y: auto;
    transition: border-color 120ms;
  }
  .sparx-input-area textarea.form-control:focus {
    outline: none !important;
    border-color: var(--sparx-color-accent) !important;
    box-shadow: 0 0 0 3px var(--sparx-color-accent-bg) !important;
  }
  .sparx-send-group {
    display: flex;
    gap: 6px;
    align-items: center;
    flex-shrink: 0;
  }
  .sparx-input-actions {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-top: 6px;
  }
  .sparx-hint {
    font-size: 10px;
    color: var(--sparx-color-text-subtle);
  }
  .sparx-stop {
    display: none !important;
  }
  .sparx-streaming .sparx-stop {
    display: inline-block !important;
  }
  .sparx-streaming #send {
    display: none !important;
  }

  /* ── Slash-command menu ──────────────────────────── */
  .sparx-slash-menu {
    position: absolute;
    bottom: 100%;
    left: 0;
    margin-bottom: 6px;
    background: var(--sparx-color-bg-surface);
    border: 1px solid var(--sparx-color-border);
    border-radius: 6px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.1);
    padding: 4px;
    min-width: 260px;
    z-index: 100;
    display: none;
    max-height: 200px;
    overflow-y: auto;
  }
  .sparx-slash-menu.active { display: block; }
  .sparx-slash-item {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 5px 8px;
    border-radius: 4px;
    cursor: pointer;
    font-size: 12px;
  }
  .sparx-slash-item:hover,
  .sparx-slash-item.selected {
    background: var(--sparx-color-accent-bg);
    color: var(--sparx-color-accent);
  }
  .sparx-slash-cmd {
    font-family: var(--sparx-font-mono);
    font-weight: 600;
    color: var(--sparx-color-accent);
  }
  .sparx-slash-desc {
    color: var(--sparx-color-text-muted);
    font-size: 11px;
  }

  /* ── System notice (compaction, etc.) ───────────── */
  .sparx-system-notice {
    margin: 10px 0;
    padding: 6px 10px;
    background: transparent;
    border-top: 1px dashed var(--sparx-color-border);
    border-bottom: 1px dashed var(--sparx-color-border);
    color: var(--sparx-color-text-subtle);
    font-size: 11px;
    text-align: center;
    font-style: italic;
  }
  .sparx-system-notice-icon {
    margin-right: 6px;
    opacity: 0.6;
  }

  /* ── Streaming text caret ────────────────────────── */
  .sparx-streaming-cursor {
    display: inline-block;
    width: 6px;
    height: 13px;
    background: var(--sparx-color-accent);
    margin-left: 2px;
    animation: sparx-blink 1s step-end infinite;
    vertical-align: middle;
  }
  @keyframes sparx-blink {
    from, to { opacity: 1; }
    50% { opacity: 0; }
  }

  /* ── Point-at highlight (from companion buddy) ─── */
  @keyframes sparx-point-highlight {
    0%   { box-shadow: 0 0 0 0 rgba(139, 92, 246, 0.5); }
    50%  { box-shadow: 0 0 0 6px rgba(139, 92, 246, 0.2); }
    100% { box-shadow: 0 0 0 0 rgba(139, 92, 246, 0); }
  }
  .companion-point-highlight {
    animation: sparx-point-highlight 1.5s ease-out;
  }

  /* ── Scrollbar polish ────────────────────────────── */
  .sparx-thread::-webkit-scrollbar {
    width: 6px;
  }
  .sparx-thread::-webkit-scrollbar-track {
    background: transparent;
  }
  .sparx-thread::-webkit-scrollbar-thumb {
    background: var(--sparx-color-border-strong);
    border-radius: 3px;
  }
  .sparx-thread::-webkit-scrollbar-thumb:hover {
    background: var(--sparx-color-text-subtle);
  }
  ",
  sep = "\n"
  )
}
