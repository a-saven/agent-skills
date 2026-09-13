# orders-demo

Tiny Express + React app used as an eval fixture. `src/` is the API, `web/` the page that calls it.

- `npm run dev` serves the API on :3000; `npm run web` serves the page on :5173 and proxies `/api`.
- Every export endpoint lives under `/api/orders/export.<format>` and is wired through `src/services/orders.ts`.
- `npm test` runs `src/services/orders.test.ts`.
