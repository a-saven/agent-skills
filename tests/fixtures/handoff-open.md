---
artifact: handoff/v1
status: open
repo: /Users/dev/orders-app
branch: feat/example
head: 3f2a9c1
created: 2026-09-13T11:40-04:00
---

# Handoff: CSV export on the orders page

## Goal
Add a "Export CSV" button to the orders list that downloads the current filter as a file.

## Done
- Export endpoint with streaming response — `src/orders/export.ts`
- Route registered — `src/routes.ts`

## In progress
The button in `src/orders/OrdersPage.tsx` renders but is not wired to the endpoint; the `onClick` handler is a stub.

## Decisions
- *user said*: server-side generation, not a client-side blob — lists can exceed 50k rows.
- *my inference*: reuse the list filter query params verbatim so the export matches what is on screen.

## Tried and failed
- Client-side `Blob` download — froze the tab on a 60k-row fixture.

## Next steps
1. Wire `onClick` in `src/orders/OrdersPage.tsx` to `GET /orders/export?<current filters>`.
2. Add a disabled state while the download is pending.
3. Run the verify commands below.

## Verify with
```
bun test src/orders
curl -sI "http://localhost:3000/orders/export?status=open" | head -n 1
```

## Open questions
- Should the export respect the user's column visibility settings?

/handoff resume
