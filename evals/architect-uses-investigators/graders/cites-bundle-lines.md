---
type: llm
focus: trace
---

The trace is the session as JSON, one message per line, with quotes and newlines escaped.

PASS if both hold:
- an Agent tool result earlier in the trace is a Context Bundle from `backend-investigator` or `frontend-investigator` that lists `path:line` entries, and
- the final reply cites at least two distinct `path:line` entries that also appear in one of those bundles — same file, same line.

FAIL if no investigator bundle came back, if the final reply cites no `path:line` entries, or if fewer than two of its citations appear in a returned bundle.
