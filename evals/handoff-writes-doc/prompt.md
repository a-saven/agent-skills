---
description: /handoff in write mode creates .claude/handoffs/<stamp>-<branch>.md with the template's sections and ends by telling the user the resume line. Needs the Write grant (--allow-tools Write); the workspace is not a git repo, so branch and head may be unknown.
tags: [handoff]
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
expected_outcome: One new file matching .claude/handoffs/*.md whose content has the Goal, Next steps and Verify with sections; the reply contains "/handoff resume" or "/agent-skills:handoff resume".
---

/handoff We were halfway through moving orders sync off the legacy HTTP client: src/orders/client.ts is rewritten, src/orders/sync.ts still imports the old client, and npm test has not been run since. Next step is to update that import and run the tests.
