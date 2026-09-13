---
description: A demonstrably local change (one file, one line, no exported symbol, route or schema) must not be delegated at all - no architect, no investigators.
tags: [architect]
max_turns: 6
allowed_tools: [Read, Glob, Grep, Agent, Skill]
expected_outcome: Zero Agent calls; the reply states the one-line fix.
---

Plan this change: in `fixtures/src/utils/date.ts` (the additional working directory) line 14 the comment says "recieve" and it should say "receive". Nothing else changes. What is the fix?
