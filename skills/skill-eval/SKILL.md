---
name: skill-eval
description: Run regression evals against skills in this repo — feeds each one a fixture task from evals/, checks the output against binary acceptance criteria in criteria.yaml, and flags drift against the last known-good run. Use before merging any change to skills/, when asked to "test the skills", "check for regressions", "run evals", or invokes /skill-eval. Read-only — it only observes and scores, never edits skills/. Agent evals (agents/*.md) are out of scope for v1.
---

# skill-eval

Regression-test harness for this repo's **skills** (`skills/<name>/SKILL.md`). Each eval case is a fixture prompt plus mechanical (and optionally LLM-judged) criteria. The runner invokes the target skill headlessly, scores output, persists JSON, and diffs against a committed baseline.

## Eval case layout

```
evals/
  <skill>/                  # must match skills/<skill>/SKILL.md (not agents/)
    <case-id>/              # kebab-case, e.g. 01-simple-feature
      task.md               # literal prompt fed to the skill under test
      criteria.yaml         # scoring rules (see schema below)
      fixture/              # optional — copied into the worktree before invoke
  results/
    .gitkeep                # tracked
    baseline.json           # tracked — last known-good; commit updates from --update-baseline
    <ISO-timestamp>-<pid>.json   # gitignored scratch runs
```

### criteria.yaml schema

```yaml
case: <skill>/<case-id>     # must match folder path
checks:
  - id: <kebab-id>
    description: <one line>
    type: mechanical | judged
    assert: <mechanical expression>   # required when type: mechanical
    judge_prompt: |                   # required when type: judged
      <prompt; model answers PASS or FAIL>
```

**Mechanical assert expressions** (evaluated against captured stdout):

| Expression | Meaning |
|---|---|
| `output contains "<text>"` | Case-sensitive substring match |
| `output does not contain "<text>"` | Substring must be absent |
| `output does not contain any of ["a", "b"]` | None of the strings may appear |
| `output matches /<regex>/` | Extended regex (Python `re`) |
| `file exists <relpath>` | File present in the case worktree |
| `file contains "<text>" in <relpath>` | Substring in a worktree file |
| `cmd exits 0: <command>` | Command run in the worktree exits 0 |

Mechanical checks run locally — no LLM call. **Judged** checks invoke `claude -p` once per check with `--model haiku` (cheap tier). The runner labels them **LLM-judged, not mechanical** in the report. Prefer mechanical wherever the criterion is structurally checkable.

## Execution model

Per case:

1. **Worktree** — `git worktree add ../skill-eval-<skill>-<case-id>-<pid> -b skill-eval/<skill>/<case-id>-<pid>` from the repo root. Then copy `skills/<skill>/` from the **working tree** (not just HEAD) into the worktree so uncommitted skill edits are what get scored. Setup failure aborts the case — never proceeds to invoke.
2. **Fixture** — if `fixture/` exists under the case dir, `cp -R` it into the worktree root before invoke.
3. **Invoke** — from the worktree, with `CLAUDE_CONFIG_DIR` pointed at a fresh config that only contains the SUT skill (so `~/.claude/skills` cannot shadow it):

   ```bash
   CLAUDE_CONFIG_DIR=<worktree>/.skill-eval-claude \
     claude -p "/<skill>

   $(cat task.md)" --output-format text
   ```

   Only skills (`skills/<name>/SKILL.md`) are supported. Transcripts are written to files and scored from those files — never passed as argv. Invocations are bounded by `SKILL_EVAL_TIMEOUT` (default 300s); timeouts use the process exit code (124) and surface as `TIMEOUT after Ns`. A non-zero non-timeout invoke is infra (exit 2), not a silent empty-output score.
4. **Score** — mechanical checks against the transcript file and/or the worktree. Judged checks: cheap-tier `claude -p` on a truncated file-backed prompt; labeled **LLM-judged, not mechanical**.
5. **Persist** — write statuses + truncated transcript to `evals/results/<ISO-timestamp>-<pid>.json`.
6. **Cleanup** — `git worktree remove --force` + delete the branch. Runs on EXIT trap even when checks fail.

## Limitations

- **Skills only.** `evals/<name>/` must correspond to `skills/<name>/SKILL.md`. Agent evals (`agents/*.md`) are not supported — subagents are invoked via the Task tool in interactive Claude Code, not via `/name` slash commands, and headless `claude -p` cannot drive that path today. `discover_cases()` fails loudly if an eval folder has no matching skill.

## Results and regression detection

- **Timestamped runs** (`evals/results/2026-09-12T14-30-00Z-12345.json`) — scratch, gitignored. Includes `output` (truncated transcript) per case.
- **Baseline** (`evals/results/baseline.json`) — committed known-good. `--update-baseline` **merges by case-id** and **refuses** if the latest run has any `fail`. A filtered run does not drop other cases from the baseline.
- On each run, if baseline exists: any check that was **pass** in baseline and **fail** now is flagged **REGRESSION** (including timeouts).

Baseline JSON shape:

```json
{
  "updated": "2026-09-12T14:30:00Z",
  "cases": {
    "orchestrate/01-simple-feature": {
      "checks": { "classified-standard": "pass", "acceptance-criteria-binary": "pass" }
    }
  }
}
```

## CLI

```bash
bin/skill-eval                                              # all cases
bin/skill-eval --skill orchestrate                          # one skill
bin/skill-eval --skill orchestrate --case 01-simple-feature # single case
bin/skill-eval --update-baseline                            # merge latest *passing* run into baseline.json
```

Exit 0 when every check passes; exit 1 on check failure or regression; exit 2 on runner/infra errors (missing `claude`, worktree setup, invoke crash).

Env vars: `SKILL_EVAL_TIMEOUT` (skill invoke, default 300), `SKILL_EVAL_JUDGE_TIMEOUT` (judged checks, default 60), `SKILL_EVAL_JUDGE_MODEL` (default `haiku`), `CLAUDE_BIN` (override claude path).

## Adding a case

1. Create `evals/<skill>/<case-id>/task.md` — the prompt. `<skill>` must exist under `skills/<skill>/SKILL.md`.
2. Create `criteria.yaml` beside it — mechanical checks first; add `type: judged` only when no structural assertion exists.
3. Run `bin/skill-eval --skill <skill> --case <case-id>`.
4. If output is correct, `bin/skill-eval --update-baseline` and commit `evals/results/baseline.json`.

**Runner self-test:** `bin/skill-eval-selftest` uses `bin/skill-eval-stub-claude` (no live API) to verify the harness itself.

## Requirements

- `claude` CLI on PATH with headless `-p` mode.
- `git` with worktree support.
- `python3` for YAML/JSON parsing (no `yq` dependency).
- Bounded invocations via `timeout` (GNU coreutils) or a built-in `python3` fallback when `timeout` is absent.
- Network + Anthropic auth for judged checks and live skill invokes.

## Non-negotiables

1. Never edit `skills/` from this skill — observe and score only.
2. Mechanical before judged. Every criterion in `criteria.yaml` must itself be binary.
3. Worktrees cleaned up on every exit path.
4. Baseline is committed; timestamped scratch runs are not.
