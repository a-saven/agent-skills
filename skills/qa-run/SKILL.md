---
name: qa-run
description: Orchestrate a manual-QA pass (functional or design) on the running app in ANY project — a WEB app in a browser or a NATIVE iOS app in the Simulator. Detects whether the project is a single app or a monorepo, remembers a dev URL and login credentials PER APP, plus an optional read-only DB, asking only for what isn't saved yet (and remembering "declined" so it never re-asks). Then scopes the run to the app(s) being tested and invokes the manual-qa agent. Use when the user asks to "QA this", "verify the app works", "test the flow", "check if X works / looks right in the browser", "test the native app / in the simulator", or invokes /qa-run. Runs in the MAIN thread (it needs to ask the user questions); it sets up context, then delegates the click-through to the manual-qa subagent. Also supports an unattended task mode where a parent injects a per-task URL/port (or Simulator UDID) + worktree and no questions are asked.
---

# qa-run — per-project QA orchestrator

You (the **main thread**) run this skill to QA a running app — **web** (browser) or **native iOS** (Simulator). The manual-qa subagent cannot prompt the user, so YOU gather per-project setup here, persist it, then spawn `manual-qa` with the resolved context. Re-run any time — saved answers are skipped.

## Config file (per project, gitignored)

State lives in `<project-root>/.claude/qa.local.json`. URLs and credentials are **per app** (a monorepo has several); the DB is project-level.

```json
{
  "version": 1,
  "apps": [
    { "name": "web-a", "url": "http://localhost:3000",
      "credentials": { "status": "set", "loginUrl": "http://localhost:3000/login", "username": "...", "password": "..." } },
    { "name": "web-b", "url": "http://localhost:3001", "credentials": { "status": "declined" } },
    { "name": "mobile", "platform": "native", "credentials": { "status": "set", "username": "...", "password": "..." } }
  ],
  "db": { "status": "set|declined|no-mcp", "access": "mcp|psql", "tool": "mcp__<server>__<readonly_sql_tool> | psql", "url": "...", "env": "local|dev|prod" }
}
```

`status` is the memory: `set` = use it · `declined` = user said no, **never ask again** · `no-mcp` = no DB MCP connected. Missing entry/field = ask. A single-app project just has one entry in `apps`. `platform` defaults to `"web"`; `"native"` marks an iOS app whose target is the Simulator, so it carries no `url` and the URL gate is skipped for it forever.

## Task mode (unattended — driven by the loop engine)

When a **parent orchestrator** invokes you for an unattended task run, it passes a resolved context and you **do not prompt the user**. The context: `{ taskId, worktree, app, url, dbUrl? }` where `url` is the task's **isolated app port** from the env manifest (e.g. `http://localhost:54123`), not the project's normal dev URL.

In task mode:
- **Use the passed `url`** as the target — skip the URL gate entirely (don't ask, don't probe the default port). A **native** task passes a Simulator UDID (`SIM_UDID`) + Xcode project/scheme instead of a `url`; pass those straight through to `manual-qa` and run it in NATIVE platform mode.
- **Creds are per app, reused across tasks.** Read the app's `credentials` from the **main repo's** `.claude/qa.local.json` (`git rev-parse --git-common-dir` → the shared repo, since this file is gitignored and won't exist in a fresh worktree checkout); a `<worktree>/.claude/qa.local.json` overrides if present. `set` → log in with them; `declined`/missing → run unauthenticated and let manual-qa emit `BLOCKED_AT_LOGIN` if it hits a wall (the loop surfaces that to the user; you never invent creds).
- **DB:** if a `dbUrl` was passed, use it read-only for the cross-check; otherwise honor the project's `db` config. Don't ask.
- Then go straight to step 8 (invoke `manual-qa`) with that context, and step 11 (report the verdict back to the loop).

The interactive steps below apply only to **human-initiated** runs (someone asks you to QA something directly).

## Steps

1. **Resolve project + config.** `root = $(git rev-parse --show-toplevel 2>/dev/null || pwd)`. Config = `$root/.claude/qa.local.json` (`Read` if present).

2. **Gitignore safety FIRST (before writing any secret).** Ensure `/.claude/qa.local.json` is in `$root/.gitignore`; append it if missing. This file holds local-dev credentials — never commit it. If you can't guarantee it's ignored, don't write creds; ask the user to use an env var instead.

3. **Detect project shape (only matters on first setup).** Monorepo if any of: root `package.json` has `workspaces`, or there's `pnpm-workspace.yaml` / `turbo.json` / `nx.json`, or multiple `apps/*/package.json`. Collect candidate apps from `apps/*` (and `packages/*` if they're runnable) and guess each dev URL from its `package.json` dev script (`--port`) or framework default. Otherwise it's a single app (name = repo dir).

4. **Scope this run.** Decide which app(s) this QA/design pass targets, and on which **platform**:
   - From the user's ask ("test **web-a** login", "check **web-b**") or from `git diff --name-only` (which `apps/*` changed).
   - If still ambiguous and there are multiple apps → **AskUserQuestion**: "Which app is in scope for this run?" (list detected apps + "all").
   - **Platform: web (default) or native iOS.** Native if the user said "native" / "iOS" / "simulator" / "the app on the phone", or the app's saved `platform` is `"native"`, or the change lives in native/React-Native/Expo/`ios/` code that no browser can exercise. A booted simulator (`orca emulator devices --json` or `xcrun simctl list devices booted`) is a strong native signal; a running dev server is a web signal. State the platform you picked. First time an app resolves to native, save `"platform": "native"` on its entry.
   - **Native run, macOS.** Prefer **Orca emulator** when available (`command -v orca` and `orca emulator --help` / `orca emulator devices --json` works) — tell `manual-qa` to drive the Simulator via `orca emulator` (tap/type/gesture/button/ax) and use `xcrun simctl` for install/launch. If Orca is missing, fall back to the **Xcode MCP** (`claude mcp get xcode`; if missing, register it with `claude mcp add -s user --transport stdio xcode -- xcrun mcpbridge`), tell the user it surfaces after a restart plus the one-time Xcode setup (Settings ▸ Intelligence ▸ "Allow external agents to use Xcode tools", Accessibility permission for the terminal when using System Events taps), and run this pass against the **web build** if neither Orca nor Xcode can drive native — otherwise stop and say native QA isn't available yet. `manual-qa` handles attaching/booting the simulator and building/launching the app.

5. **URL gate (per in-scope WEB app) — LOCAL FIRST.** Skip this entirely for a native app — its target is the Simulator, not a URL (an Expo app being tested in a browser is a *web* run and does need one). For each web app in scope, if its `url` isn't saved:
   - **Probe local before asking.** Read `.claude/qa.local.json` and probe the app's expected local dev port(s) — from its `package.json` dev script (`--port`), the framework default, or the common set (`3000 3001 8081 5173 4321 19006`) — with `curl -sI` / `lsof -i -P | grep LISTEN`. If a local server is already serving the app, use it and skip the prompt.
   - Nothing local running → **AskUserQuestion / prompt**: "What URL should I use for **<app>**?" — pre-fill the detected port (e.g. `http://localhost:3000`). On a monorepo first-run, offer to capture URLs for **all** detected apps at once so it remembers them all. Write each into `apps[].url`.
   - Prefer a live port: confirm with `curl -sI <url>` / `lsof -i -P | grep LISTEN`. If the server's down, ask whether to start it (background it, wait for the port) — don't assume.
   - **A deployed preview / dev / staging URL is a LAST resort** — reach for it only when no local app is reachable (and per the non-localhost risk warning below). Never jump to a preview link while a local server is (or could be) running.
   - **Non-localhost target = the user's risk.** localhost / `127.0.0.1` / `0.0.0.0` is the safe default. The user *may* point QA at any other host (staging, a deployed preview, even prod), and you should allow it — but if the URL isn't local, **warn once before using it**: QA drives a real browser against a live, possibly shared environment, so it can submit forms, trigger writes, send emails, and hit real services and rate limits. State plainly that **all risk is on the user**, proceed only on their explicit confirmation, then save the URL as given (re-warning isn't needed once it's saved). Don't refuse it — just make the risk explicit.

6. **Credentials gate (per in-scope app).** For each in-scope app:
   - `credentials.status: "set"` → use them.
   - `"declined"` → proceed without login (authenticated flows can't be exercised).
   - missing → **AskUserQuestion**: "manual-qa can log into **<app>** to verify authenticated flows. Provide credentials?" → **Provide** (then ask `loginUrl | username | password`, write `status:set`) / **Decline (don't ask again for this app)** (write `status:declined`). Push for local-dev creds; if the app's URL is non-localhost, the same "all risk on the user" warning from the URL gate covers the creds you're about to use against that live environment.

7. **DB gate (project-level).** If `db.status` is set/declined → honor it. Otherwise detect a DB MCP (`claude mcp list` → match, case-insensitive, `db|database|postgres|supabase|sql|dbhub|mysql|mongo|sqlite|mariadb|cockroach|neon|planetscale|prisma`):
   - **MCP found (e.g. Supabase)** → **AskUserQuestion** "Use **<server>** to read this project's DB during QA? Provide a read-only DB URL." → Provide (write `status:set`, `access:"mcp"`, `tool`, `url`) / Decline (`status:declined`, never ask again).
   - **No MCP found** → **AskUserQuestion** "No DB MCP connected. How should I verify DB writes?" with options:
     - **Install a DB MCP** (Supabase, Postgres, etc.) → point the user at the install, skip the DB step this run, leave `db` unset (or write `no-mcp`) so it re-asks once the MCP is connected.
     - **Use `psql` with a DB URL I provide** → ask for the URL, write `status:set`, `access:"psql"`, `tool:"psql"`, `url`. All queries run read-only via `psql "<url>" -c "…"`.
     - **Decline (don't ask again)** → `status:declined`.
   - **The DB URL must be a local or dev database.** Say this explicitly when asking. If the user hands over a **production** URL, warn once that QA will read prod and that they're accepting the risk; proceed only on explicit confirmation, record `env:"prod"`, and never run anything but read-only queries.

8. **Invoke `manual-qa`** (Agent tool), once per in-scope app, with a self-contained prompt: the **platform** (web or native, and why you picked it), for native whether **Orca emulator** or **Xcode MCP** should drive the Simulator (probe Orca first), the **mode** (functional vs design — infer from the ask), the app's **url** (web) or the Xcode project/workspace + scheme and booted simulator UDID/name if you know them (native), its **credentials** if `status:set` (tell it to log in via the UI first), and — for design — the Figma link found in the conversation or a request to the user for a Figma link / screenshot. State whether DB verification is available.

9. **Handle a login block.** If manual-qa returns `BLOCKED_AT_LOGIN: <what>` (needed auth, none provided), **ping the user**: "manual-qa is blocked at login for **<app>** — provide credentials now? (saved to this project)". Yes → collect, store `status:set`, re-invoke. No → report what was/wasn't verifiable.

10. **DB cross-check** (only if `db.status:"set"`): after manual-qa confirms a UI write, run the configured read-only SQL — via the DB MCP (`access:"mcp"`) or `psql "<url>" -c "…"` (`access:"psql"`) — to confirm the row changed; fold into the report. Read-only — never mutate. If `env:"prod"`, double down: SELECT only.

11. **Report.** Relay manual-qa's verdict (PASS/FAIL/PARTIAL) + findings/differences + anything unverified, plus the DB confirmation if run. For multiple in-scope apps, one section per app.

## Rules

- **Never commit credentials.** Gitignore the config before writing; never paste passwords into chat/reports (redact).
- **Target URL: localhost by default, non-localhost at the user's own risk.** Default to and prefer a local URL. Any non-localhost target (staging/preview/prod) is allowed only after an explicit one-time warning that QA will exercise a live, possibly shared environment and **all risk is on the user**, plus their confirmation. Don't refuse it.
- **DB URL: local/dev by default.** Push the user toward a local or dev DB. A prod URL is allowed only after an explicit risk warning + confirmation (record `env:"prod"`), and even then queries stay strictly read-only.
- **Respect saved choices forever** — `declined` / `no-mcp` are standing per-app/per-project decisions; don't re-ask. The user changes their mind by editing `.claude/qa.local.json`.
- **Ask only for what's missing.** Saved URL → don't re-ask. New app in scope with no saved URL/creds → ask just for that app.
- **You ask; the agent acts.** All AskUserQuestion prompts happen here in the main thread.
- A project may ship its own `.claude/agents/manual-qa.md` to override the global agent — that's expected.
