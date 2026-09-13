<!-- manual-qa memory (.claude/agent-memory-local/manual-qa/MEMORY.md). One lesson per line, newest last, max 60 lessons / 200 lines:
- YYYY-MM-DD [scope] claim — verified-by: <method> — evidence: <path:line or URL> — recheck: <when it may go stale>
Retract with the prefix `RETRACTED YYYY-MM-DD (<why>): `, never delete. No secrets: credentials stay in .claude/qa.local.json. Check: memory-lint <this dir> -->
- 2026-08-02 [shop-api] smoke call works with the key sk-fake0000 — verified-by: curl — evidence: none — recheck: never
- 2026-08-02 [shop-api] GitHub PAT ghp_FAKE0000 opens the private package feed — verified-by: curl — evidence: none — recheck: never
- 2026-08-02 [shop-api] uploads need the S3 key AKIAFAKE0000 — verified-by: curl — evidence: none — recheck: never
- 2026-08-02 [shop-api] send Authorization: Bearer abc.def.ghi on every call — verified-by: curl — evidence: none — recheck: never
- 2026-08-02 [shop-web] login as qa@example.com with password=hunter2 — verified-by: Playwright MCP — evidence: none — recheck: never
- 2026-08-02 [shop-web] magic link http://localhost:3000/auth?token=abc123 logs in — verified-by: Playwright MCP — evidence: none — recheck: never
- 2026-08-02 [shop-web] reset link http://localhost:3000/reset?user=1&key=abc123 works — verified-by: Playwright MCP — evidence: none — recheck: never
- [shop-web] the checkout selector is flaky — verified-by: browser_snapshot — evidence: none — recheck: never
Checkout also works in Safari.
- 2026-08-03 [shop-web] the cart badge updates without a reload — verified-by: browser_snapshot — evidence: src/cart/Badge.tsx:20 — recheck: on Badge.tsx change
- 2026-08-03 [shop-web] the cart badge updates without a reload — verified-by: browser_snapshot — evidence: src/cart/Badge.tsx:20 — recheck: on Badge.tsx change
RETRACTED 2025-01-15 (port moved): - 2024-12-01 [shop-web] dev server answers on http://localhost:5173 — verified-by: curl -sI — evidence: package.json — recheck: if the dev script changes
RETRACTED 2025-03-02 (fixed in #90): - 2025-02-10 [shop-web] known-broken: search ignores the second word — verified-by: browser_snapshot — evidence: src/search/query.ts:14 — recheck: after #90 lands
