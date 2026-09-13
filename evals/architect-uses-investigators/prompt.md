---
description: A cross-boundary change (API route + page) must be scouted by the investigators before the architect designs, and the plan must cite files as path:line. Both graders are scored in both arms on purpose; this case guards the mechanism, not the delta.
tags: [architect]
max_turns: 40
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Agent, Skill]
expected_outcome: At least one Agent call whose subagent_type is frontend-investigator or backend-investigator; the final reply contains at least one path:line citation.
---

Plan adding a CSV export of orders to the small app in the additional working directory (`fixtures/app`: an Express API under `src/`, a React page under `web/`). It should sit next to the existing JSON export and be reachable from the orders page the same way. Put the plan in your reply rather than a file: backend, frontend, how to verify, and cite every file you relied on as path:line.
