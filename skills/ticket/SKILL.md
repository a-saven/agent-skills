---
name: ticket
description: Create Linear or Jira tickets that read like a human wrote them — not AI slop. Detects which tracker a project uses (Linear vs Jira) and remembers the team/project mapping per project, asking only once. Handles both bug reports and new-feature handoffs, written for the tester who picks it up — a bug gets reproduction steps + where it lives; a feature gets what it solves, where to find it, the design, and how to test it. Writes a short, scannable ticket (plain language, real paths/flows, concrete test steps, observable acceptance) and enriches it from whatever useful MCPs are connected — renders Figma frames, pulls Sentry error context, reads the originating Slack thread, links the relevant PR — using only what's installed and relevant. Posts recent test results (qa-run, test runs, CI) and long evidence as a comment instead of bloating the description. Use when the user asks to "create a ticket", "file a bug", "open an issue", "make a Linear/Jira ticket", "log this", or invokes /ticket. Runs in the MAIN thread so it can read the conversation and confirm the draft before creating.
---

# ticket — human-readable Linear / Jira ticket creator

You (the **main thread**) run this skill to turn a request or a chunk of the current conversation into a clean, human-readable ticket in the project's tracker. The whole point is **no AI slop**: short, specific, scannable, written like a teammate filed it. You already have the conversation in context — mine it for the problem, the design links, and the test results; don't make the user repeat themselves.

## Scope — global default, project override

This is the **global** ticket skill — it works in any project **except** ones that should use their own ticket workflow instead. **Before anything else, check whether the current project owns ticket creation, and if so stand down:**

- **Project ships its own ticket skill** — if the repo has a project-scoped ticket/issue-creation skill under `<root>/.claude/skills/`, or one named in its `CLAUDE.md`, defer to it. A project skill named `ticket` already overrides this one automatically; this guard also covers skills with a *different* name.
- **Local opt-out list** — if `~/.claude/ticket-defer-repos.txt` exists, read it: one repo identifier per line (matched against `git config --get remote.origin.url` / `git remote -v`). If the current repo matches any line, **do not run this skill** — defer to that repo's own ticket workflow and tell the user you're using its standard, not this global one. The list is local and uncommitted, so private repo names never leave the machine.

Everywhere else, proceed with the steps below.

## Config (per project)

State lives in `<project-root>/.claude/tickets.local.json`. It holds **no secrets** (just the tracker choice + team/project mapping), so a team may commit it as `.claude/tickets.json` to share. Read both if present; `tickets.local.json` wins.

```jsonc
{
  "version": 1,
  "tracker": "linear",            // "linear" | "jira"
  "linear": {
    "team":    { "id": "…", "key": "ENG", "name": "Engineering" },
    "project": { "id": "…", "name": "Web app" },   // or null
    "defaultLabels": ["bug"]                          // optional
  },
  "jira": {
    "cloudId":   "…",            // Atlassian site id
    "project":   { "key": "PROJ", "name": "…" },
    "defaultIssueType": "Bug"    // Bug | Task | Story
  }
}
```

Tracker tool names are **detected live each session** (MCP names change) — never store them. Missing config → run the detect + mapping gates once, then write it.

## Steps

1. **Resolve project + check scope.** `root = $(git rev-parse --show-toplevel 2>/dev/null || pwd)`. **First apply the scope guard above** — if this repo ships its own ticket skill or matches the local defer list, stop here and defer. Otherwise read `$root/.claude/tickets.json` then `$root/.claude/tickets.local.json` (local wins).

2. **Detect the tracker** (only if `tracker` not in config):
   - List connected MCP tools (`claude mcp list`, and the deferred-tool list in this session). **Linear** = a tool whose name contains `linear` and creates issues (e.g. `…Linear__save_issue`). **Jira** = an `…Atlassian__…` or `…jira…` MCP.
   - Corroborate from the repo: Jira if branch/commit identifiers look like `ABC-123` (`git log --oneline -20`, `git branch --show-current`); Linear if commits/PRs reference `ENG-123`-style ids or a `.linear` config exists.
   - **Both available / ambiguous** → AskUserQuestion: "Which tracker does this project use?" (Linear / Jira). **Only one** → use it. **Neither** → stop and tell the user to connect a **Linear** or **Atlassian (Jira)** MCP (via claude.ai integrations or `claude mcp add`), then re-run.
   - Save the choice.

3. **Map team / project** (only if not in config). Load the tracker's read tools via `ToolSearch` and call them:
   - **Linear** — `list_teams` → AskUserQuestion which team (store `id/key/name`). Then `list_projects` for that team → ask which project (or "none"). Optionally `list_issue_labels` to offer default labels.
   - **Jira** — find the Atlassian MCP; if it isn't authenticated, run its `authenticate` tool and walk the user through `complete_authentication` first. Then list sites (cloudId) and projects → ask which project + default issue type.
   - Save the mapping so this gate never runs again.

4. **Mine the conversation for content.** From the request + recent context, pull:
   - **The core point** — in plain words: for a **bug**, the broken behavior; for a **feature**, the functionality added and the problem it solves / what the user can now do.
   - **Where it lives / where to find it** — for a **bug**, the real file/component/endpoint (`src/auth/middleware.ts`, the `POST /orders` handler); for a **feature**, how a *tester* reaches it (the page/screen/flow + entry point, plus any flag, role, or test data needed). Name it; never write "the relevant module".
   - **Reproduction** (bug) or **how to test** (feature) — concrete, numbered steps with the expected result, from what was actually discussed. Write them so QA can follow without guessing.
   - **Design / references** — every `figma.com` link, Claude/v0/preview design URL, and screenshot or image path shared in the conversation.
   - **Test results** — the most recent qa-run / manual-qa verdict, `npm test`/`pytest`/CI output, or repro logs. These go in a **comment**, not the body (step 8).
   - **The flow** — when the ticket involves multi-step or multi-component logic (a request path, state machine, async chain, permission cascade), note the actual path (user action → component → endpoint → data) so you can diagram it in the draft.
   - One request may be several tickets ("create tickets for X, Y, Z") → draft one ticket **per distinct problem**. Don't cram unrelated things into one.

5. **Enrich from any connected MCP** that adds real signal. Check what's connected (`claude mcp list` + this session's deferred-tool list) and pull context for *this* ticket only — never invent, never dump a dashboard:
   - **Figma** (`…Figma__…`) — for any `figma.com` link in the chat: `get_screenshot` to render the actual frame (attach the image, not just the URL) and `get_design_context` / `get_metadata` / `get_variable_defs` for the intended layout, components, and key tokens (sizes, colors, spacing). Turns a bare link into a real **Design** section the implementer can build to.
   - **Sentry** (`…Sentry__…`) — if the bug references an error, stack trace, or Sentry link: `get_issue_full_context` / `get_issue_debug_summary` for the real exception, affected releases/users, and top frames. One-line summary + link in the body; the full trace goes in the comment (step 8).
   - **Slack** (`…Slack__…`) — if the report came from a thread (link, or "as discussed in #channel"): read it for the original context/decision and link it as the source.
   - **GitHub / git** — link the relevant PR, commit, or branch (`gh pr view`, `git log`) so the ticket points at the code in flight.
   - **PostHog / Grafana / Supabase** — only when the ticket is about metrics or data: pull one concrete number (error rate, affected row count, funnel drop), not a dashboard dump.
   - **Notion / Google Drive** — if a spec/PRD is referenced, link the doc instead of paraphrasing it.
   - Rule: use an MCP **only if it's installed AND relevant to this ticket**. Each pull must earn its place — one line of real signal beats a paragraph of filler. Connected-but-irrelevant or not-connected → skip silently.

6. **Draft using the anti-slop template** (below). Then **show the rendered draft(s) to the user for a quick confirm** before creating — unless they said "just create it / don't ask". Let them edit title/labels/scope inline. This review step is what keeps tickets human.

7. **Create the issue** via the tracker's create tool (load its schema with `ToolSearch` first):
   - **Linear** — `save_issue` with `title`, `description` (markdown), `teamId`, `projectId` (if set), `labelIds` (map default labels). Attach each design link / screenshot with `create_attachment` (or upload via `prepare_attachment_upload` → `create_attachment_from_upload` for local image files) so they show as real attachments, not just inline text.
   - **Jira** — create the issue under the mapped project + issue type with a markdown/ADF description. Add design links as remote links or in a **References** section; upload screenshot files as attachments if the MCP supports it, else link them.

8. **Post test results (and other long evidence) as a comment** (not in the description) when the conversation has a recent run: `save_comment` (Linear) / the Jira comment tool. Keep it human — a one-line verdict plus the key pass/fail lines and a timestamp, e.g. *"QA run 2026-06-18: login + checkout PASS; discount code FAIL (total ignores code) — see body."* Full Sentry traces or logs gathered in step 5 go here too. Don't paste the entire dump; link it or trim to the failing lines.

9. **Report back** the created ticket's identifier + URL (one line per ticket). If a draft was rejected, don't create it.

## The anti-slop ticket template

Write it the way a good engineer files a ticket for the teammate who picks it up next — often a **tester / QA**, not just the implementer. **Pick Bug or Feature by the request.** A feature ticket isn't a dev spec: a tester reading it must come away knowing **what it does / what problem it solves, where to find it, the design, and exactly how to test it**. Include only the sections that have real content — delete the rest. Markdown.

**Bug**
````markdown
**What's happening**
<1–2 plain sentences: the observed broken behavior.>

**Where**
<the real file / component / page / endpoint — name it.>

**Steps to reproduce**
1. …
2. …
- Expected: …
- Actual: …

**How it flows**            ← only for multi-step / multi-component logic
```mermaid
flowchart LR
  User -->|clicks Pay| Checkout --> API["POST /orders"] --> DB[(orders)]
  API -. breaks here .-> X[total ignores discount]
```
<one line: what the diagram shows and where it breaks.>

**Likely cause**            ← only if you actually have a lead
<one line — the suspected root cause.>

**Design / references**     ← only if links/screenshots exist
- Figma: <link>
- <screenshot / preview link>

**How to verify the fix**
- [ ] <observable outcome, not an implementation step>
- [ ] …
````

**Feature / task** — written so a tester can pick it up and verify it
````markdown
**What & why**
<1–2 plain sentences: the functionality added and the problem it solves / what the user can now do. The point, not a feature list.>

**Where to find it**
<how a tester reaches it: the page / screen / flow + entry point, plus any flag, role, or test data needed to see it.>

**How it flows**            ← only for multi-step / multi-component logic
```mermaid
flowchart LR
  User -->|uploads CSV| ImportPage --> API["POST /imports"] --> Queue --> Worker --> DB[(rows)]
```
<one line: what the diagram shows — the happy path a tester walks.>

**Design**                  ← only if links/screenshots exist
- Figma: <link>             (frame rendered + attached if a Figma MCP is connected)
- <screenshot of the intended result>

**How to test**
1. <concrete step a tester follows>
2. …
- Expected: <what they should see / be able to do>

**Done when**
- [ ] <observable outcome a tester can confirm>
- [ ] …

**Out of scope**            ← only if worth calling out
- <what this does not cover yet>
````

## Rules — what keeps it human, not AI slop

- **Title says the actual thing, ≤ ~70 chars.** Bug → the broken behavior ("Checkout total ignores discount code"). Feature → what's new ("Add CSV export to the reports page"). Never "Implement a comprehensive solution for…".
- **Plain, direct voice.** Present tense, like a Slack message to a colleague. No throat-clearing ("This ticket aims to…"), no restating the title in the first line.
- **Ban filler.** No *comprehensive / robust / seamless / powerful / leverage / utilize*, no emoji spam, no "As an AI". Cut every word that adds no information.
- **Be specific.** Real file paths, real symbols, real URLs, real numbers — never "the relevant component" or "various places".
- **Short beats complete-looking.** A small bug is a few lines. Don't manufacture sections or nested bullet trees to look thorough. Omit empty sections entirely.
- **One problem per ticket.** Split a multi-part request into multiple tickets.
- **Diagram complex flow; skip trivial ones.** When the logic spans multiple components or steps (request path, state machine, async chain, permission cascade), add ONE small Mermaid diagram (`flowchart` or `sequenceDiagram`, ~5–10 nodes) in the **How it flows** section so a human grasps the flow at a glance — label the arrows with what actually happens ("clicks Pay", "retries 3×"), and in a bug mark where it breaks. Linear renders Mermaid natively; in Jira it shows as a code block, which is still readable — keep it small enough to read as text. A one-screen bug or single-component change gets **no diagram** — a forced diagram is its own kind of slop.
- **Always testable.** Every ticket — bug or feature — ends with steps a tester can follow and observable outcomes to confirm, never a re-listing of the implementation steps. A feature without "where to find it" + "how to test" is unfinished.
- **Evidence lives in a comment.** Full logs, stack traces, complete test output → step 8's comment, so the description stays scannable.
- **Confirm before creating** (unless told not to). Surface the draft; the user's quick edit is the last guard against slop.
- **Respect saved config.** Tracker + team/project are decided once; don't re-ask. The user changes them by editing `.claude/tickets.local.json`.
