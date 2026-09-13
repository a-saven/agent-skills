<!-- manual-qa memory index (.claude/agent-memory-local/manual-qa/MEMORY.md). One pointer line per lesson, newest last, max 60 lessons / 200 lines:
- [Title](topic-slug.md) — YYYY-MM-DD [scope] claim — verified-by: <method> — evidence: <path:line or URL> — recheck: <when it may go stale>
The detail lives in the linked topic file beside this one. Retract with the prefix `RETRACTED YYYY-MM-DD (<why>): `, never delete. No secrets here or in a topic file: credentials stay in .claude/qa.local.json. Check: memory-lint <this dir> -->
- [API smoke](api-smoke.md) — 2026-08-02 [shop-api] the smoke call works with the key sk-fake0000 — verified-by: curl — evidence: none — recheck: never
- [Package feed](package-feed.md) — 2026-08-02 [shop-api] the GitHub PAT ghp_FAKE0000 opens the private package feed — verified-by: curl — evidence: none — recheck: never
- [Uploads](uploads.md) — 2026-08-02 [shop-api] uploads need the S3 key AKIAFAKE0000 — verified-by: curl — evidence: none — recheck: never
- [Auth header](auth-header.md) — 2026-08-02 [shop-api] send Authorization: Bearer abc.def.ghi on every call — verified-by: curl — evidence: none — recheck: never
- [Login](login.md) — 2026-08-02 [shop-web] log in as qa@example.com with password=hunter2 — verified-by: Playwright MCP — evidence: none — recheck: never
- [Magic link](magic-link.md) — 2026-08-02 [shop-web] the magic link http://localhost:3000/auth?token=abc123 logs in — verified-by: Playwright MCP — evidence: none — recheck: never
- [Reset link](reset-link.md) — 2026-08-02 [shop-web] the reset link http://localhost:3000/reset?user=1&key=abc123 works — verified-by: Playwright MCP — evidence: none — recheck: never
- [Planning style](planning-style.md) — how this reviewer likes plans written
- [Release notes](2026-08-02-release.md) — [shop-web] the release page renders — verified-by: browser_snapshot — evidence: none — recheck: never
- [Cart badge](cart-badge.md) — 2026-08-03 the cart badge updates without a reload — verified-by: browser_snapshot — evidence: src/cart/Badge.tsx:20 — recheck: on Badge.tsx change
- [Search filters](search-filters.md) — 2026-09-01 [shop-web] the filters persist in the URL — verified-by: browser_snapshot — evidence: src/search/Filters.tsx:31 — recheck: on Filters.tsx change
Checkout also works in Safari.
- [Cart badge](cart-badge.md) — 2026-08-03 the cart badge updates without a reload — verified-by: browser_snapshot — evidence: src/cart/Badge.tsx:20 — recheck: on Badge.tsx change
RETRACTED 2025-01-15 (port moved): - 2024-12-01 [shop-web] the dev server answers on http://localhost:5173 — verified-by: curl -sI — evidence: package.json — recheck: if the dev script changes
RETRACTED 2025-03-02 (fixed in #90): - 2025-02-10 [shop-web] known-broken: search ignores the second word — verified-by: browser_snapshot — evidence: src/search/query.ts:14 — recheck: after #90 lands
