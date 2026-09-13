#!/bin/sh
# Builds the repository this case plans against, in the eval run's empty workspace.
# Deterministic: same bytes every run. The orders chain is the change's slice; the generated
# widget modules are the noise it has to be traced out of, so the prompt can name nothing.
set -eu

mkdir -p src/routes src/services src/db/queries src/lib src/types src/tests \
  web/src/api web/src/hooks web/src/components web/src/pages

cat > package.json <<'EOF'
{
  "name": "ops-console",
  "private": true,
  "scripts": {
    "dev": "tsx src/server.ts",
    "web": "vite --config web/vite.config.ts",
    "test": "vitest run",
    "check-types": "tsc --noEmit"
  },
  "dependencies": {
    "express": "^4.19.2",
    "pg": "^8.12.0",
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "devDependencies": {
    "tsx": "^4.19.0",
    "typescript": "^5.6.0",
    "vite": "^5.4.0",
    "vitest": "^2.1.0"
  }
}
EOF

cat > README.md <<'EOF'
# ops-console

Internal console for the wholesale back office. `src/` is the Express API, `web/` the React client.

- `npm run dev` serves the API on :3000; `npm run web` serves the client on :5173 and proxies `/api`.
- `npm test` runs the vitest suite under `src/tests/`; `npm run check-types` must pass before review.
- `src/db/schema.sql` is the source of truth for the database — this demo applies it by hand.
EOF

cat > src/server.ts <<'EOF'
import express from "express";
import { registerOrderRoutes } from "./routes/orders";
import { registerGeneratedRoutes } from "./routes/generated";
import { errorHandler } from "./lib/http";

const app = express();
app.use(express.json());

registerOrderRoutes(app);
registerGeneratedRoutes(app);

app.use(errorHandler);

const port = Number(process.env.PORT ?? 3000);
app.listen(port, () => {
  console.log(`api listening on ${port}`);
});

export { app };
EOF

cat > src/lib/http.ts <<'EOF'
import type { NextFunction, Request, Response } from "express";

export type Handler = (req: Request, res: Response) => Promise<void> | void;

export class HttpError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

export function badRequest(message: string): HttpError {
  return new HttpError(400, message);
}

export function notFound(message: string): HttpError {
  return new HttpError(404, message);
}

export function route(handler: Handler) {
  return (req: Request, res: Response, next: NextFunction): void => {
    Promise.resolve(handler(req, res)).catch(next);
  };
}

export function sendAttachment(res: Response, filename: string, contentType: string, body: string): void {
  res.setHeader("Content-Disposition", `attachment; filename="${filename}"`);
  res.setHeader("Cache-Control", "no-store");
  res.type(contentType).send(body);
}

export function errorHandler(err: unknown, _req: Request, res: Response, _next: NextFunction): void {
  const status = err instanceof HttpError ? err.status : 500;
  const message = err instanceof Error ? err.message : "internal error";
  if (status >= 500) console.error(err);
  res.status(status).json({ error: message });
}
EOF

cat > src/lib/filters.ts <<'EOF'
import type { Request } from "express";
import { badRequest } from "./http";
import { ORDER_SORTS, ORDER_STATUSES } from "../types/order";
import type { OrderFilter, OrderSort, OrderStatus } from "../types/order";

export const MAX_PAGE_SIZE = 200;
export const DEFAULT_PAGE_SIZE = 50;

function one(req: Request, key: string): string | undefined {
  const value = req.query[key];
  return typeof value === "string" && value.length > 0 ? value : undefined;
}

function integer(raw: string | undefined, fallback: number, key: string): number {
  if (raw === undefined) return fallback;
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 0) throw badRequest(`${key} must be a non-negative integer`);
  return value;
}

export function parseOrderFilter(req: Request): OrderFilter {
  const status = one(req, "status");
  if (status && !ORDER_STATUSES.includes(status as OrderStatus)) {
    throw badRequest(`unknown status: ${status}`);
  }

  const sort = one(req, "sort") ?? "created_at_desc";
  if (!ORDER_SORTS.includes(sort as OrderSort)) {
    throw badRequest(`unknown sort: ${sort}`);
  }

  const since = one(req, "since");
  if (since && Number.isNaN(Date.parse(since))) {
    throw badRequest(`since must be an ISO date: ${since}`);
  }

  const limit = integer(one(req, "limit"), DEFAULT_PAGE_SIZE, "limit");
  if (limit < 1 || limit > MAX_PAGE_SIZE) throw badRequest(`limit must be 1..${MAX_PAGE_SIZE}`);

  return {
    status: status as OrderStatus | undefined,
    since,
    search: one(req, "q"),
    sort: sort as OrderSort,
    limit,
    offset: integer(one(req, "offset"), 0, "offset"),
  };
}

export function exportFilter(filter: OrderFilter, limit: number): OrderFilter {
  return { ...filter, limit, offset: 0 };
}

export function filterCacheKey(filter: OrderFilter): string {
  return [filter.status ?? "-", filter.since ?? "-", filter.search ?? "-", filter.sort].join("|");
}

export function describeFilter(filter: OrderFilter): string {
  const parts = [filter.status ?? "all statuses", filter.sort];
  if (filter.since) parts.push(`since ${filter.since}`);
  if (filter.search) parts.push(`matching "${filter.search}"`);
  return parts.join(", ");
}
EOF

cat > src/types/order.ts <<'EOF'
export const ORDER_STATUSES = ["pending", "paid", "shipped", "refunded"] as const;
export type OrderStatus = (typeof ORDER_STATUSES)[number];

export const ORDER_SORTS = ["created_at_desc", "created_at_asc", "total_desc"] as const;
export type OrderSort = (typeof ORDER_SORTS)[number];

export const EXPORT_FORMATS = ["json"] as const;
export type ExportFormat = (typeof EXPORT_FORMATS)[number];

export type OrderFilter = {
  status?: OrderStatus;
  since?: string;
  search?: string;
  sort: OrderSort;
  limit: number;
  offset: number;
};

export type OrderLine = {
  lineId: string;
  sku: string;
  description: string;
  quantity: number;
  unitPriceCents: number;
};

export type Order = {
  id: string;
  reference: string;
  customerName: string;
  customerEmail: string;
  status: OrderStatus;
  currency: string;
  totalCents: number;
  createdAt: string;
  lines: OrderLine[];
};

export type OrderRow = Omit<Order, "lines">;

export type OrderPage = {
  rows: Order[];
  total: number;
};

export type ExportResult = {
  body: string;
  filename: string;
  contentType: string;
};
EOF

cat > src/db/client.ts <<'EOF'
import { Pool } from "pg";
import type { QueryResultRow } from "pg";

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: Number(process.env.PG_POOL_MAX ?? 10),
});

export async function query<T extends QueryResultRow>(sql: string, params: unknown[] = []): Promise<T[]> {
  const result = await pool.query<T>(sql, params);
  return result.rows;
}

export async function queryOne<T extends QueryResultRow>(sql: string, params: unknown[] = []): Promise<T | undefined> {
  const rows = await query<T>(sql, params);
  return rows[0];
}

export async function close(): Promise<void> {
  await pool.end();
}
EOF

cat > src/db/queries/orders.ts <<'EOF'
import { query, queryOne } from "../client";
import type { OrderFilter, OrderLine, OrderRow, OrderStatus } from "../../types/order";

const ORDER_COLUMNS = `
  o.id,
  o.reference,
  o.customer_name  AS "customerName",
  o.customer_email AS "customerEmail",
  o.status,
  o.currency,
  o.total_cents    AS "totalCents",
  o.created_at     AS "createdAt"
`;

const SORTS: Record<OrderFilter["sort"], string> = {
  created_at_desc: "o.created_at DESC",
  created_at_asc: "o.created_at ASC",
  total_desc: "o.total_cents DESC, o.created_at DESC",
};

function where(filter: OrderFilter, params: unknown[]): string {
  const clauses: string[] = [];
  if (filter.status) {
    params.push(filter.status);
    clauses.push(`o.status = $${params.length}`);
  }
  if (filter.since) {
    params.push(filter.since);
    clauses.push(`o.created_at >= $${params.length}`);
  }
  if (filter.search) {
    params.push(`%${filter.search}%`);
    clauses.push(`(o.reference ILIKE $${params.length} OR o.customer_email ILIKE $${params.length})`);
  }
  return clauses.length > 0 ? `WHERE ${clauses.join(" AND ")}` : "";
}

export async function selectOrders(filter: OrderFilter): Promise<OrderRow[]> {
  const params: unknown[] = [];
  const clause = where(filter, params);
  params.push(filter.limit, filter.offset);
  return query<OrderRow>(
    `SELECT ${ORDER_COLUMNS} FROM orders o ${clause}
      ORDER BY ${SORTS[filter.sort]}
      LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params,
  );
}

export async function countOrders(filter: OrderFilter): Promise<number> {
  const params: unknown[] = [];
  const clause = where(filter, params);
  const row = await queryOne<{ count: string }>(`SELECT count(*)::text AS count FROM orders o ${clause}`, params);
  return Number(row?.count ?? 0);
}

export async function countByStatus(filter: OrderFilter): Promise<{ status: OrderStatus; count: number }[]> {
  const params: unknown[] = [];
  const clause = where({ ...filter, status: undefined }, params);
  const rows = await query<{ status: OrderStatus; count: string }>(
    `SELECT o.status, count(*)::text AS count FROM orders o ${clause} GROUP BY o.status`,
    params,
  );
  return rows.map((row) => ({ status: row.status, count: Number(row.count) }));
}

export async function selectOrderByReference(reference: string): Promise<OrderRow | undefined> {
  return queryOne<OrderRow>(`SELECT ${ORDER_COLUMNS} FROM orders o WHERE o.reference = $1`, [reference]);
}

export async function selectLinesForOrders(orderIds: string[]): Promise<(OrderLine & { orderId: string })[]> {
  if (orderIds.length === 0) return [];
  return query<OrderLine & { orderId: string }>(
    `SELECT l.id AS "lineId",
            l.order_id AS "orderId",
            l.sku,
            l.description,
            l.quantity,
            l.unit_price_cents AS "unitPriceCents"
       FROM order_lines l
      WHERE l.order_id = ANY($1)
      ORDER BY l.order_id, l.sku`,
    [orderIds],
  );
}
EOF

cat > src/db/schema.sql <<'EOF'
-- Source of truth for the ops-console database. Applied by hand in this demo.

CREATE TABLE orders (
  id             text PRIMARY KEY,
  reference      text NOT NULL UNIQUE,
  customer_name  text NOT NULL,
  customer_email text NOT NULL,
  status         text NOT NULL CHECK (status IN ('pending', 'paid', 'shipped', 'refunded')),
  currency       char(3) NOT NULL DEFAULT 'USD',
  total_cents    integer NOT NULL CHECK (total_cents >= 0),
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE order_lines (
  id               text PRIMARY KEY,
  order_id         text NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
  sku              text NOT NULL,
  description      text NOT NULL,
  quantity         integer NOT NULL CHECK (quantity > 0),
  unit_price_cents integer NOT NULL CHECK (unit_price_cents >= 0)
);

-- The list screen filters on status and always sorts by created_at.
CREATE INDEX orders_status_created_at ON orders (status, created_at DESC);
CREATE INDEX orders_created_at ON orders (created_at DESC);
CREATE INDEX orders_reference_trgm ON orders USING gin (reference gin_trgm_ops);

-- Lines are only ever read per order, in sku order.
CREATE INDEX order_lines_order_id ON order_lines (order_id, sku);
EOF

cat > src/services/orders.ts <<'EOF'
import { countByStatus, countOrders, selectLinesForOrders, selectOrderByReference, selectOrders } from "../db/queries/orders";
import { notFound } from "../lib/http";
import { ORDER_STATUSES } from "../types/order";
import type { ExportFormat, ExportResult, Order, OrderFilter, OrderLine, OrderPage, OrderStatus } from "../types/order";

export const EXPORT_LIMIT = 5000;

function attachLines(rows: Awaited<ReturnType<typeof selectOrders>>, lines: (OrderLine & { orderId: string })[]): Order[] {
  const byOrder = new Map<string, OrderLine[]>();
  for (const line of lines) {
    const { orderId, ...rest } = line;
    const bucket = byOrder.get(orderId) ?? [];
    bucket.push(rest);
    byOrder.set(orderId, bucket);
  }
  return rows.map((row) => ({ ...row, lines: byOrder.get(row.id) ?? [] }));
}

export async function listOrders(filter: OrderFilter): Promise<OrderPage> {
  const [rows, total] = await Promise.all([selectOrders(filter), countOrders(filter)]);
  const lines = await selectLinesForOrders(rows.map((row) => row.id));
  return { rows: attachLines(rows, lines), total };
}

export async function getOrder(reference: string): Promise<Order> {
  const row = await selectOrderByReference(reference);
  if (!row) throw notFound(`no order with reference ${reference}`);
  const lines = await selectLinesForOrders([row.id]);
  return attachLines([row], lines)[0];
}

export function formatMoney(cents: number, currency: string): string {
  return `${(cents / 100).toFixed(2)} ${currency}`;
}

export function orderSummary(order: Order): string {
  return `${order.reference} — ${order.customerName} — ${formatMoney(order.totalCents, order.currency)}`;
}

export function orderAgeDays(order: Order, now = new Date()): number {
  const ms = now.getTime() - new Date(order.createdAt).getTime();
  return Math.max(0, Math.floor(ms / 86_400_000));
}

export async function statusCounts(filter: OrderFilter): Promise<Record<OrderStatus, number>> {
  const counts = Object.fromEntries(ORDER_STATUSES.map((status) => [status, 0])) as Record<OrderStatus, number>;
  for (const row of await countByStatus(filter)) {
    counts[row.status] = row.count;
  }
  return counts;
}

export async function exportOrders(filter: OrderFilter, format: ExportFormat): Promise<ExportResult> {
  const page = await listOrders({ ...filter, limit: EXPORT_LIMIT, offset: 0 });
  if (format === "json") {
    return {
      body: JSON.stringify(page.rows, null, 2),
      filename: "orders.json",
      contentType: "application/json",
    };
  }
  throw new Error(`unsupported export format: ${format}`);
}
EOF

cat > src/routes/orders.ts <<'EOF'
import type { Express } from "express";
import { describeFilter, parseOrderFilter } from "../lib/filters";
import { badRequest, route, sendAttachment } from "../lib/http";
import { exportOrders, getOrder, listOrders } from "../services/orders";
import { EXPORT_FORMATS } from "../types/order";
import type { ExportFormat } from "../types/order";

export function registerOrderRoutes(app: Express): void {
  app.get(
    "/api/orders",
    route(async (req, res) => {
      const filter = parseOrderFilter(req);
      res.setHeader("X-Filter", describeFilter(filter));
      res.json(await listOrders(filter));
    }),
  );

  app.get(
    "/api/orders/export.:format",
    route(async (req, res) => {
      const format = req.params.format as ExportFormat;
      if (!EXPORT_FORMATS.includes(format)) throw badRequest(`unsupported export format: ${format}`);
      const { body, filename, contentType } = await exportOrders(parseOrderFilter(req), format);
      sendAttachment(res, filename, contentType, body);
    }),
  );

  app.get(
    "/api/orders/:reference",
    route(async (req, res) => {
      res.json(await getOrder(req.params.reference));
    }),
  );
}
EOF

cat > src/tests/orders.test.ts <<'EOF'
import { describe, expect, it, vi } from "vitest";
import * as queries from "../db/queries/orders";
import { exportOrders, formatMoney, listOrders } from "../services/orders";
import type { OrderFilter } from "../types/order";

const filter: OrderFilter = { sort: "created_at_desc", limit: 50, offset: 0 };

const row = {
  id: "o1",
  reference: "SO-1001",
  customerName: "Acme Supply",
  customerEmail: "ap@acme.example",
  status: "paid" as const,
  currency: "USD",
  totalCents: 129900,
  createdAt: "2026-09-01T10:00:00Z",
};

const line = {
  lineId: "l1",
  orderId: "o1",
  sku: "WID-9",
  description: "Widget, large",
  quantity: 3,
  unitPriceCents: 43300,
};

function stubDb() {
  vi.spyOn(queries, "selectOrders").mockResolvedValue([row]);
  vi.spyOn(queries, "countOrders").mockResolvedValue(1);
  vi.spyOn(queries, "selectLinesForOrders").mockResolvedValue([line]);
}

describe("listOrders", () => {
  it("attaches lines to their order", async () => {
    stubDb();
    const page = await listOrders(filter);
    expect(page.total).toBe(1);
    expect(page.rows[0].lines).toHaveLength(1);
  });
});

describe("exportOrders", () => {
  it("serialises the filtered orders as json", async () => {
    stubDb();
    const result = await exportOrders(filter, "json");
    expect(result.filename).toBe("orders.json");
    expect(JSON.parse(result.body)).toHaveLength(1);
  });
});

describe("formatMoney", () => {
  it("renders cents as a decimal amount", () => {
    expect(formatMoney(129900, "USD")).toBe("1299.00 USD");
  });
});
EOF

cat > web/src/api/client.ts <<'EOF'
export class ApiError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

export type QueryParams = Record<string, string | number | undefined>;

export function withQuery(path: string, params: QueryParams): string {
  const qs = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== "") qs.set(key, String(value));
  }
  const suffix = qs.toString();
  return suffix ? `${path}?${suffix}` : path;
}

export async function getJson<T>(path: string): Promise<T> {
  const res = await fetch(path, { headers: { accept: "application/json" } });
  if (!res.ok) throw new ApiError(res.status, `${path} failed with ${res.status}`);
  return (await res.json()) as T;
}
EOF

cat > web/src/api/orders.ts <<'EOF'
import { getJson, withQuery } from "./client";
import type { QueryParams } from "./client";
import type { ExportFormat, OrderFilter, OrderPage } from "../../../src/types/order";

export const PAGE_SIZE = 50;

export type OrdersQuery = Partial<Pick<OrderFilter, "status" | "since" | "search" | "sort">> & {
  page?: number;
};

function params(query: OrdersQuery): QueryParams {
  return {
    status: query.status,
    since: query.since,
    q: query.search,
    sort: query.sort ?? "created_at_desc",
    limit: PAGE_SIZE,
    offset: (query.page ?? 0) * PAGE_SIZE,
  };
}

export function fetchOrders(query: OrdersQuery): Promise<OrderPage> {
  return getJson<OrderPage>(withQuery("/api/orders", params(query)));
}

export function exportUrl(query: OrdersQuery, format: ExportFormat): string {
  const { limit: _limit, offset: _offset, ...rest } = params(query);
  return withQuery(`/api/orders/export.${format}`, rest);
}
EOF

cat > web/src/hooks/useOrders.ts <<'EOF'
import { useCallback, useEffect, useState } from "react";
import { fetchOrders } from "../api/orders";
import type { OrdersQuery } from "../api/orders";
import type { OrderPage } from "../../../src/types/order";

const EMPTY: OrderPage = { rows: [], total: 0 };

export type OrdersState = {
  page: OrderPage;
  loading: boolean;
  error: string | undefined;
  reload: () => void;
};

export function useOrders(query: OrdersQuery): OrdersState {
  const [page, setPage] = useState<OrderPage>(EMPTY);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | undefined>(undefined);
  const key = JSON.stringify(query);

  const load = useCallback(() => {
    let cancelled = false;
    setLoading(true);
    setError(undefined);
    fetchOrders(JSON.parse(key) as OrdersQuery)
      .then((next) => {
        if (!cancelled) setPage(next);
      })
      .catch((e: Error) => {
        if (!cancelled) setError(e.message);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [key]);

  useEffect(() => load(), [load]);

  return { page, loading, error, reload: load };
}

export function useDebounced<T>(value: T, ms = 250): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), ms);
    return () => clearTimeout(timer);
  }, [value, ms]);
  return debounced;
}
EOF

cat > web/src/components/OrdersToolbar.tsx <<'EOF'
import { exportUrl } from "../api/orders";
import type { OrdersQuery } from "../api/orders";
import { ORDER_SORTS, ORDER_STATUSES } from "../../../src/types/order";

type Props = {
  query: OrdersQuery;
  total: number;
  onChange: (next: OrdersQuery) => void;
};

export function OrdersToolbar({ query, total, onChange }: Props) {
  return (
    <header className="toolbar">
      <select
        value={query.status ?? ""}
        onChange={(e) => onChange({ ...query, status: (e.target.value || undefined) as OrdersQuery["status"], page: 0 })}
      >
        <option value="">All statuses</option>
        {ORDER_STATUSES.map((status) => (
          <option key={status} value={status}>
            {status}
          </option>
        ))}
      </select>

      <select
        value={query.sort ?? "created_at_desc"}
        onChange={(e) => onChange({ ...query, sort: e.target.value as OrdersQuery["sort"], page: 0 })}
      >
        {ORDER_SORTS.map((sort) => (
          <option key={sort} value={sort}>
            {sort}
          </option>
        ))}
      </select>

      <input
        type="search"
        placeholder="reference or email"
        value={query.search ?? ""}
        onChange={(e) => onChange({ ...query, search: e.target.value || undefined, page: 0 })}
      />

      <span className="count">{total} orders</span>

      <a className="button" href={exportUrl(query, "json")} download>
        Export JSON
      </a>
    </header>
  );
}
EOF

cat > web/src/components/OrdersTable.tsx <<'EOF'
import type { Order } from "../../../src/types/order";

type Props = {
  rows: Order[];
  loading: boolean;
};

function money(cents: number, currency: string): string {
  return `${(cents / 100).toFixed(2)} ${currency}`;
}

export function OrdersTable({ rows, loading }: Props) {
  if (loading) return <p className="muted">Loading orders…</p>;
  if (rows.length === 0) return <p className="muted">No orders match these filters.</p>;

  return (
    <table>
      <thead>
        <tr>
          <th>Reference</th>
          <th>Customer</th>
          <th>Status</th>
          <th>Lines</th>
          <th>Total</th>
          <th>Placed</th>
        </tr>
      </thead>
      <tbody>
        {rows.map((order) => (
          <tr key={order.id}>
            <td>{order.reference}</td>
            <td title={order.customerEmail}>{order.customerName}</td>
            <td>{order.status}</td>
            <td>{order.lines.length}</td>
            <td>{money(order.totalCents, order.currency)}</td>
            <td>{new Date(order.createdAt).toLocaleDateString()}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
EOF

cat > web/src/pages/OrdersPage.tsx <<'EOF'
import { useState } from "react";
import { OrdersTable } from "../components/OrdersTable";
import { OrdersToolbar } from "../components/OrdersToolbar";
import { useOrders } from "../hooks/useOrders";
import { PAGE_SIZE } from "../api/orders";
import type { OrdersQuery } from "../api/orders";

export function OrdersPage() {
  const [query, setQuery] = useState<OrdersQuery>({ sort: "created_at_desc", page: 0 });
  const { page, loading, error, reload } = useOrders(query);
  const pages = Math.max(1, Math.ceil(page.total / PAGE_SIZE));
  const current = query.page ?? 0;

  return (
    <section className="orders">
      <OrdersToolbar query={query} total={page.total} onChange={setQuery} />

      {error ? (
        <p className="error">
          {error} <button onClick={reload}>Retry</button>
        </p>
      ) : null}

      <OrdersTable rows={page.rows} loading={loading} />

      <footer className="pager">
        <button disabled={current === 0} onClick={() => setQuery({ ...query, page: current - 1 })}>
          Previous
        </button>
        <span>
          Page {current + 1} of {pages}
        </span>
        <button disabled={current + 1 >= pages} onClick={() => setQuery({ ...query, page: current + 1 })}>
          Next
        </button>
      </footer>
    </section>
  );
}
EOF

i=1
while [ "$i" -le 10 ]; do
  n=$(printf '%02d' "$i")
  sed "s/NN/$n/g" > "src/services/sNN.ts.tmp" <<'EOF'
import { query } from "../db/client";

export type WidgetNN = {
  id: string;
  label: string;
  updatedAt: string;
};

export async function listWidgetsNN(limit = 25): Promise<WidgetNN[]> {
  return query<WidgetNN>(
    'SELECT id, label, updated_at AS "updatedAt" FROM widgets_NN ORDER BY label LIMIT $1',
    [limit],
  );
}
EOF
  mv "src/services/sNN.ts.tmp" "src/services/s$n.ts"

  sed "s/NN/$n/g" > "src/routes/rNN.ts.tmp" <<'EOF'
import type { Express } from "express";
import { route } from "../lib/http";
import { listWidgetsNN } from "../services/sNN";

export function registerRNN(app: Express): void {
  app.get(
    "/api/widgets-NN",
    route(async (_req, res) => {
      res.json(await listWidgetsNN());
    }),
  );
}
EOF
  mv "src/routes/rNN.ts.tmp" "src/routes/r$n.ts"

  sed "s/NN/$n/g" > "web/src/components/cNN.tsx.tmp" <<'EOF'
import { useEffect, useState } from "react";
import { getJson } from "../api/client";
import type { WidgetNN } from "../../../src/services/sNN";

export function WidgetNNPanel() {
  const [rows, setRows] = useState<WidgetNN[]>([]);
  useEffect(() => {
    getJson<WidgetNN[]>("/api/widgets-NN").then(setRows);
  }, []);
  return (
    <ul className="widgets-NN">
      {rows.map((row) => (
        <li key={row.id}>{row.label}</li>
      ))}
    </ul>
  );
}
EOF
  mv "web/src/components/cNN.tsx.tmp" "web/src/components/c$n.tsx"
  i=$((i + 1))
done

{
  echo 'import type { Express } from "express";'
  i=1
  while [ "$i" -le 10 ]; do
    printf 'import { registerR%02d } from "./r%02d";\n' "$i" "$i"
    i=$((i + 1))
  done
  echo
  echo 'export function registerGeneratedRoutes(app: Express): void {'
  i=1
  while [ "$i" -le 10 ]; do
    printf '  registerR%02d(app);\n' "$i"
    i=$((i + 1))
  done
  echo '}'
} > src/routes/generated.ts

{
  i=1
  while [ "$i" -le 10 ]; do
    printf 'import { Widget%02dPanel } from "../components/c%02d";\n' "$i" "$i"
    i=$((i + 1))
  done
  echo
  echo 'export function WidgetsPage() {'
  echo '  return ('
  echo '    <section className="widgets">'
  i=1
  while [ "$i" -le 10 ]; do
    printf '      <Widget%02dPanel />\n' "$i"
    i=$((i + 1))
  done
  echo '    </section>'
  echo '  );'
  echo '}'
} > web/src/pages/WidgetsPage.tsx
