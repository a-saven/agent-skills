---
name: worktree-graphs
description: >-
  Check, seed, or repair the CodeGraph index and Graphify graph across a repo's git
  worktrees. Use when a session is running in a worktree and CodeGraph looks absent or
  wrong, when the user asks whether the graphs are fresh / "check all worktrees", after
  creating a worktree (Orca, `git worktree add`, or an agent harness), or when a graph
  answer disagrees with the code actually on disk. Also covers why a Graphify graph goes
  stale after `git pull` and how to force a refresh.
---

# Worktree graphs

A repo's code graphs are **per-checkout, gitignored build artifacts**. A fresh `git worktree`
therefore starts with none — so a session running there silently loses CodeGraph entirely and
falls back to grep. `graphs` fixes that in one command.

## Check everything first

```bash
graphs status
```

One row per worktree (main included): branch, CodeGraph state, Graphify state.

| Reading | Means |
|---|---|
| `cg: 5081f/63424n fresh` | indexed, nothing pending — trust it |
| `cg: … +12 pending` | 12 files changed since the last sync — run `graphs sync` |
| `cg: MISSING` | no index here; this session is grep-only — run `graphs seed` |
| `cg: … BORROWED-INDEX` | **the danger case**: resolving another checkout's index, so answers describe a different branch's code |
| `gf: snapshot(main)` | read-only architectural graph copied from main — expected in a worktree |
| `gf: own build, 45d old` | this worktree built its own graph (e.g. a `post-checkout` hook did) and nothing refreshes it |
| `gf: STALE (5 commits behind)` | main's graph predates HEAD — run `graphs sync` in main |

## Fix

```bash
graphs seed              # give every worktree that lacks them an index + graph snapshot (free)
graphs sync              # refresh the graphs for the checkout you are in
graphs prune --merged    # reclaim disk from worktrees whose branch is already merged
graphs ensure            # what the SessionStart hook runs: seed if missing, then sync in background
```

`seed` reflink-clones main's index (`cp -c`): 3 copies of a 251 MB database cost 8 KB, measured.
It deliberately does **not** sync — `codegraph sync` rewrites enough pages to break block sharing
and materialise the full file (~300 MB per worktree). So seeding every worktree is free, and only
the worktree you actually open pays. `graphs prune [--merged]` gives the disk back.

## What each graph is good for

- **CodeGraph** is branch-accurate. Every worktree gets its **own** index, synced to its own
  HEAD and working tree, so a symbol that exists only on this branch is found here and is
  invisible from main. This is the one to trust for "where is X / who calls X".
- **Graphify** is an architectural overview (`graphify-out/GRAPH_REPORT.md`, cross-app
  concepts and flows). Its node ids embed the main checkout's absolute path, so re-extracting
  it inside a worktree would duplicate every node. Worktrees therefore get a **read-only
  snapshot of main's graph** and never refresh it locally. That is deliberate: use it for
  orientation, not for branch-specific claims.

## Gotchas worth knowing

- **A worktree created outside a Claude session has no graphs until a session opens there.**
  The SessionStart hook seeds on entry, which is when they are first needed.
- **Hooks in `.husky/` can be skipped.** A GUI or daemon-launched `git worktree add` runs with
  a minimal `PATH`, so a `post-checkout` hook guarded on `command -v graphify` exits silently.
  `graphs` resolves tool paths itself instead of trusting `PATH`.
- **Graphify goes stale after `git pull`, not after your commits.** A sync triggered only by
  local commits never sees merges you pulled in. `graphs` compares
  `graphify-out/.synced-sha` against `HEAD` and syncs the whole range.
- **Never point two checkouts at one index.** Each worktree owns its database file; sharing
  one means concurrent writers and answers from the wrong branch.
