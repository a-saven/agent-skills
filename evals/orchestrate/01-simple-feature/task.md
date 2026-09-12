Add a `--dry-run` flag to `bin/graphs status` that prints what actions it would take (seed codegraph/graphify into worktrees, spawn background sync jobs) without writing anything or forking background processes.

Constraints:
- Only modify `bin/graphs` — no new files.
- The flag must work as `bin/graphs status --dry-run`.
- Output must be human-readable, one line per would-be action.

Deliver: a task DAG with nodes, routing tiers, and binary acceptance criteria per node. Do not implement — plan only.
