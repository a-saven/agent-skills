---
name: playwright-qa
description: Fast, headless functional browser testing for any local web app via the global Playwright MCP — click-through flows, form submit + assert, login-gated paths, forced API-error states, mobile-viewport / offline / geolocation checks, and trace evidence. This is the DEFAULT and required way to drive a real browser for web QA (not unit/component tests); the Orca browser CLI is the fallback when the MCP tools aren't loaded, and Maestro covers native mobile apps. Triggers: "test the flow", "click through", "verify in the browser", "headless e2e", "reproduce the bug in the UI", "check the error state", "test mobile viewport".
---

# Playwright QA (headless, via Playwright MCP)

A global, reusable browser-driving tool for functional QA in **any** local project. The Playwright MCP server is installed at **user scope**, so its tools are available in every project — no per-repo setup.

- **Server:** `@playwright/mcp@latest --headless` (Microsoft, official), stdio, user scope. Install with `claude mcp add -s user playwright -- npx @playwright/mcp@latest --headless` (the repo's `install.sh` does this).
- **Tools:** `mcp__playwright__browser_*`. They may be deferred — load schemas on demand with `ToolSearch` (e.g. `select:browser_navigate,browser_snapshot,browser_click,browser_type`). If they don't appear at all, the MCP was just added → **restart Claude Code once** to surface them.
- **First run** downloads Chromium (one-time, ~100MB) — expect a short delay on the first `browser_navigate`. Pre-install it with `npx playwright install chromium` if you're about to need a browser in a hurry.
- **The user wants to WATCH the run?** The MCP is headless by design and its flags are fixed once the server boots, so no MCP call can put a window on screen. Run a headed throwaway script from the scratchpad instead — `chromium.launch({ headless: false, slowMo: 250 })` — and keep the MCP for everything unattended. Full guidance in the `manual-qa` agent under "Headless by default — a VISIBLE browser when the user asks to watch".

## Pick the right tool

| Need | Tool |
|------|------|
| Fast/repeatable **functional** click-through of a web app | **Playwright MCP** (this skill) |
| Force an **API error / mock / block** a request (4xx/5xx/offline) | **Playwright MCP** |
| **Mobile viewport / device / geolocation / offline** behavior | **Playwright MCP** |
| Log in once, **reuse the session** across runs | **Playwright MCP** `storageState` |
| **Design / visual** confirmation, or the MCP tools aren't loaded this session | **Playwright MCP** screenshot; else the **Orca** browser CLI |
| Native **mobile app** flow | **Maestro** (not a browser) |
| Component render assertions (no real browser) | the project's unit runner |

Why Playwright leads: accessibility-tree snapshots with **stable refs** (no pixel guessing), **auto-waiting** (no flaky sleeps), **headless** (off the desktop, parallel, cross-platform/CI), plus network/viewport/offline control. When its tools aren't in the list, drive **Orca** (`orca tab create --url`, `orca snapshot`, `orca click --element @e1`, `orca screenshot`, `orca set offline|device`, `orca storage local set`) — a real browser with an equivalent surface. Never fall back to reading code instead of driving a browser.

## The loop

`navigate → snapshot → act (by ref) → re-snapshot / assert`.

1. `browser_navigate { url }` — go to the page.
2. `browser_snapshot` — accessibility tree; each interactive element has a **ref** (e.g. `textbox "Email" [ref=e5]`).
3. Act: `browser_click { ref, element }`, `browser_type { ref, element, text, submit? }`, `browser_fill_form { fields }`, `browser_select_option`, `browser_press_key`, `browser_hover`.
4. Wait on a real signal: `browser_wait_for { text | textGone | time }` (actions auto-wait; use this for navigations/async UI).
5. Assert: re-`browser_snapshot`, or `browser_evaluate { function }` for DOM/URL/values; `browser_console_messages` + `browser_network_requests` for errors and API calls.
6. Evidence: `browser_take_screenshot`; capture console/network output verbatim.

Selectors: target the app's existing **roles / labels / testIDs** rather than brittle CSS.

## High-value capabilities (reach for these)

- **Network control** — intercept/mock/abort requests to force error states, assert which requests fired, replay HAR.
- **Emulation** — `browser_resize` / device profiles for mobile breakpoints; geolocation, offline, locale, color-scheme.
- **Auth reuse** — sign in once, save `storageState` (cookies + localStorage), reuse across runs. Note SPA tokens may live in localStorage, not cookies.
- **Trace** — produce a trace.zip as QA evidence (`npx playwright show-trace`); `npx playwright codegen <url>` records clicks into a script you can hand to a test-author.

## Project setup (generic)

- **Login credentials** for authenticated flows come from the per-project config the `qa-run` skill manages (`<project>/.claude/qa.local.json`, gitignored, local-dev only). Log in through the real UI, then optionally save `storageState` to reuse.
- **Find the app URL**: prefer a running dev port (`lsof -i -P | grep LISTEN`, `curl -sI`), else read `package.json` scripts. Start a dev server only if asked (background it, wait for the port).
- **DB verification** (confirm a UI write persisted) is optional and handled by `qa-run` using the project's read-only DB MCP, if configured.
- **Native mobile** flows → Maestro, not Playwright.

## Report format

Charter → Verdict (PASS/FAIL/PARTIAL) → numbered steps+observations (real refs/URLs) → findings (severity, exact symptom) → unverified. Every PASS must trace to something observed in the browser. Quote console/network errors verbatim. Never put credentials in the report — redact.
