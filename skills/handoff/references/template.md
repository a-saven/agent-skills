---
artifact: handoff/v1
status: open
repo: <absolute path to the repo root>
branch: <current branch, or none>
head: <short sha at write time, or none>
created: <YYYY-MM-DDTHH:MM±HH:MM>
---

# Handoff: <the goal in eight words or fewer>

## Goal
<What the user wants, one or two sentences, in their words where possible.>

## Done
<One line per finished piece, each ending with the path it lives in.>
- <what> — `<path>`

## In progress
<The single thing mid-flight: which file, what exists, what is missing.>

## Decisions
<One per line. The tag tells the next session what it may revisit.>
- *user said*: <a choice the user made — not negotiable without asking them>
- *my inference*: <a choice you made, and why>

## Tried and failed
<Abandoned approaches and the reason, so nobody retries them.>
- <approach> — <why not>

## Next steps
<Numbered. Step 1 must be runnable exactly as written.>
1. <command / file to edit / check to make>
2. <…>

## Verify with
<Exact commands that prove the work is intact: tests, lint, a curl.>
```
<command>
```

## Open questions
<Only things the user can answer. "none" is a valid answer.>
- <question>

<Last line, verbatim: /handoff resume for a symlink install, /agent-skills:handoff resume for the plugin>
/handoff resume
