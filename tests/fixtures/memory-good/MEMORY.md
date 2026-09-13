<!-- manual-qa memory (.claude/agent-memory-local/manual-qa/MEMORY.md). One lesson per line, newest last, max 60 lessons / 200 lines:
- YYYY-MM-DD [scope] claim — verified-by: <method> — evidence: <path:line or URL> — recheck: <when it may go stale>
Retract with the prefix `RETRACTED YYYY-MM-DD (<why>): `, never delete. No secrets: credentials stay in .claude/qa.local.json. Check: memory-lint <this dir> -->
- 2026-08-02 [shop-web] dev server answers on http://localhost:3000, not the 5173 in package.json — verified-by: curl -sI — evidence: .claude/qa.local.json apps[0].url — recheck: if the dev script changes
- 2026-08-02 [shop-web] every page past /login is auth-gated; log in first with the shop-web creds in .claude/qa.local.json — verified-by: Playwright MCP login — evidence: http://localhost:3000/login — recheck: when auth changes
- 2026-08-19 [shop-web] checkout "Place order": role=button name="Place order" is stable, the data-testid was renamed twice — verified-by: browser_snapshot ref — evidence: src/checkout/Summary.tsx:88 — recheck: on any Summary.tsx change
- 2026-08-19 [shop-web] forced 500 on POST /api/orders shows the inline error and keeps the cart — verified-by: Playwright route mock — evidence: src/checkout/useOrder.ts:41 — recheck: if error handling moves
RETRACTED 2026-09-01 (fixed in #142): - 2026-08-19 [shop-web] known-broken: empty cart renders a blank page instead of the empty state — verified-by: browser_snapshot — evidence: src/cart/Cart.tsx:12 — recheck: after #142 lands
- 2026-09-01 [shop-web] known-broken: the order-history date column shows UTC, ticket #150 — verified-by: browser_snapshot vs API response — evidence: src/orders/History.tsx:57 — recheck: after #150 lands
- 2026-09-01 [shop-ios] Orca emulator drives the Simulator; Xcode MCP hangs at tools/list until "Allow external agents" is on — verified-by: orca emulator ax --json — evidence: Xcode ▸ Settings ▸ Intelligence — recheck: after an Xcode update
