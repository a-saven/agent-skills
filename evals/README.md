# evals

Behavioural cases for `claude plugin eval` (Claude Code 2.1.269 or later). Every case runs the model three times, so a full run costs money and is never part of CI. Run it by hand from the repo root:

    claude plugin eval . --trust-plugin --max-cost-usd 5 --no-publish --allow-tools Write --ablation none --scaffold

| Case | Checks |
|---|---|
| `architect-uses-investigators` | Planning a spreadsheet export of the orders list dispatches a `*-investigator` subagent, and the plan cites at least two `path:line` entries that came back in a bundle. The architect makes that Agent call one level down; whether `tool_used` counts nested calls is unconfirmed until the first paid run — if not, reword the prompt so the main thread dispatches the scouts itself. |
| `architect-local-change-no-scouts` | A one-line typo fix dispatches nothing: zero Agent calls, the reply names the fix. |
| `handoff-writes-doc` | `/handoff` writes `.claude/handoffs/<stamp>-<branch>.md` with the template's sections and ends with the resume line. Needs `--allow-tools Write`. |

**`architect-uses-investigators` generates its repository.** It used to plan against a 9-file, ~150-line app committed under `fixtures/`, and in four headless runs on 2.1.270 the architect read all nine files itself and reported that a scout could add nothing — the right call on a repo that size, which left the case testing nothing. `scaffold.sh` now writes the workspace instead: 50 files / 1,207 lines, of which the export's slice — the files the change edits plus one hop of imports either way — is 16 files / 697 lines, over both halves of the architect's skip rule (at most 8 files AND at most 600 lines), and still 13 files / 605 lines on the narrowest reading of what the change edits. The generated `r*`/`s*`/`c*` widget modules are noise; the prompt names no file or directory, so the route → service → schema → component chain only comes out of tracing imports. The script is deterministic — byte-identical on a second run — but `--scaffold` runs it as you, outside the agent's sandbox, so read it before you pass the flag. Without `--scaffold` the workspace is empty and the case scores 0.

`cites-bundle-lines` is an `llm` grader over the trace, and a judge sees only the first 12 and last 12 messages of it. The architect dispatches in Step 0, so the bundles should land inside the first 12 — if that grader fails while the plan plainly cites bundle lines, suspect the truncation before the plugin.

`--ablation none` skips the without-plugin arm: it cannot pass the mechanism graders, so its `Δ` says nothing and would double the bill. Iterate on one case with `--case <name> --runs 1`; add `--ablation with-without` only when you want the comparison anyway. Results land in `evals/results/` (gitignored).
