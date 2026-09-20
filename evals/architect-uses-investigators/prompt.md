---
description: A change whose slice spans a route, its service, its schema and the component that renders it must be scouted before the architect designs, and the plan must cite files the scouts returned. The prompt names no file, so the chain only comes out of tracing imports. Needs --scaffold.
tags: [architect]
max_turns: 60
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Agent, Skill]
expected_outcome: At least one Agent call whose subagent_type is frontend-investigator or backend-investigator; the final reply cites at least two path:line entries that came back in a Context Bundle.
---

Operators want to pull the orders they are currently looking at — same filters, same sort — out of this app as a spreadsheet they can open in Excel: one row per line item, with the order's reference, customer and status repeated on every row. Before they commit to the download they want to see how many rows it will be.

Plan it against this repository: what changes where, in edit order; the contract between the parts; how to verify it. Cite every file you relied on as `path:line`. Put the plan in your reply, not in a file.
