# evals

Behavioural cases for `claude plugin eval` (Claude Code 2.1.269 or later). Every case runs the model three times, so a full run costs money and is never part of CI. Run it by hand from the repo root:

    claude plugin eval . --trust-plugin --max-cost-usd 5 --no-publish --allow-tools Write --ablation none

| Case | Checks |
|---|---|
| `architect-uses-investigators` | Planning a CSV export for the fixture app under the case's `fixtures/` dispatches a `*-investigator` subagent, and the plan cites files as `path:line`. The architect makes that Agent call one level down; whether `tool_used` counts nested calls is unconfirmed until the first paid run — if not, reword the prompt so the main thread dispatches the scouts itself. |
| `architect-local-change-no-scouts` | A one-line typo fix dispatches nothing: zero Agent calls, the reply names the fix. |
| `handoff-writes-doc` | `/handoff` writes `.claude/handoffs/<stamp>-<branch>.md` with the template's sections and ends with the resume line. Needs `--allow-tools Write`. |

`--ablation none` skips the without-plugin arm: it cannot pass the mechanism graders, so its `Δ` says nothing and would double the bill. Iterate on one case with `--case <name> --runs 1`; add `--ablation with-without` only when you want the comparison anyway. Results land in `evals/results/` (gitignored).
