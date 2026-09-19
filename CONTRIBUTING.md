# Contributing

Everything in this repo ends up in someone's context window. A change is good when it makes a skill or agent fire on the right prompt, do the job, and cost as little as possible the rest of the time.

## Frontmatter

- `description:` is the only part of a skill or agent that loads in every session (the skill list and the Agent tool's agent list). Write it trigger-only: what it does in one clause, the phrases and situations that should fire it, then what it is not for. One double-quoted line of strict YAML (inner quotes as `\"`), 500 characters or fewer. `bin/check` warns above 500 and fails above 1024.
- `name:` equals the directory (`skills/<name>/SKILL.md`) or the filename (`agents/<name>.md`).
- Agents: `model: inherit|haiku|sonnet|opus`. `memory: local|project|user` only on agents that have a Learning loop section. `tools:` whenever the agent must not inherit everything; the investigators list theirs without `Agent` so they cannot nest, and `bin/check` enforces both. `effort: low|medium|high|xhigh|max` when the agent should not inherit the session level (the investigators run `medium`; levels are model-dependent per the docs).

## Bodies

- A body loads only when the skill or agent is invoked, and all of it does. Keep it under about 200 lines; past that, move reference material to `skills/<name>/references/<topic>.md` and link it from the body. `bin/check` verifies every such link resolves.
- Plain, specific, second person to the agent. No marketing words, no emoji. Read two neighbouring files first so yours is indistinguishable from them.
- An agent that reports ends with a fixed output contract: section order and what a line looks like. If you change a contract, update every consumer the file names.
- Label every claim about behaviour: measured, observed on <Claude Code version>, or expected. No invented numbers.

## Memory lines

Agents with `memory:` keep a memory directory in the project they run in, and Claude Code names it after the agent as invoked — `.claude/agent-memory-local/architect/` under a symlink install, `.claude/agent-memory-local/agent-skills-architect/` under the plugin (observed on 2.1.270). Its `MEMORY.md` is an index, one pointer line per lesson, and the detail lives in a topic file beside it:

    - [Title](topic-slug.md) — YYYY-MM-DD [scope] claim — verified-by: <method> — evidence: <path:line or URL> — recheck: <when it may go stale>

Every line loads on every spawn of that agent, so the 60-lesson cap is a budget, not a target. The date and the `[scope]` come after the link (a date in the file name does not count) and the linked file must exist. Retract by prefixing `RETRACTED YYYY-MM-DD (<why>): `, never by deleting, so a wrong lesson is not re-learned. Never secrets, tokens, cookies, query-string URLs or personal data, in the index or in a topic file; credentials stay in `.claude/qa.local.json` and are referenced by path. `bin/memory-lint <file>` checks this — the contract on the index, the secret patterns on the topic files too; `hooks/memory-guard.sh` runs it against both directory names when `architect` or `manual-qa` stops and hands the first 8 lint lines back once (a one-shot repair prompt: with `stop_hook_active: true` the agent may still finish with an invalid file). A new memory agent must be added to the SubagentStop matcher in `hooks/hooks.json` and `install.sh`. `tests/fixtures/memory-good/` and `memory-bad/` show a passing and a failing directory.

## Scripts and hooks

POSIX sh (`#!/bin/sh`, `set -eu`) unless bash is genuinely needed; `bin/check` runs `sh -n` or `bash -n` by shebang. Every script runs on macOS (BSD userland, bash 3.2 as `sh`) and Linux (GNU or uutils coreutils, dash, mawk), and CI runs `bin/check` on both. Use POSIX flags; where none exists, order the fallback so the first form fails cleanly on the other platform and check what comes back — GNU `stat -f` prints filesystem status before failing, so `stat -c %Y` goes before `stat -f %m`, and `date -v-8d` before `date -d '8 days ago'`. Use `grep -E` rather than `\|` in a basic regex. Hooks finish in under 2 s and exit 0 with no output on any failure. Almost no comments: one line for a non-obvious why, nothing that restates the code.

## Before a PR

    bin/check            # frontmatter, references, sh -n, tests, claude plugin validate, JSON
    bin/check --budget   # per-file description and body sizes

CI runs `bin/check --strict`, where a skipped check fails. `claude --plugin-dir . plugin details agent-skills` prints the always-on token estimate; quote it in the PR whenever you touch a description, next to the same command run on `main` (the installed form, `claude plugin details agent-skills`, uses a different estimator, so never mix the two).

## Adding an eval case

Behavioural checks live in `evals/<case>/`: `prompt.md` (the prompt a user would type, plus `max_turns` and `allowed_tools`) and `graders/*.md`, with a `case.yaml` when the case needs fixtures (`context.add_dirs`). Give each case one grader on the result and one on how Claude got there (`tool_used`, `tool_order`), and prefer `regex`, `tool_used` and `file_exists`, which are free, over `llm`. Fixtures go inside the case directory; a run cannot read anything else in the repo. Evals call the model and cost money, so they are run by hand, not in CI: see `evals/README.md`.
