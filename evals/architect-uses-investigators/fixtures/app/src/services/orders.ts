import { query } from "../db/client";

export type Order = {
  id: string;
  customerEmail: string;
  status: "pending" | "paid" | "refunded";
  totalCents: number;
  createdAt: string;
};

export type OrderFilter = { status?: string };

export async function listOrders(filter: OrderFilter): Promise<Order[]> {
  const where = filter.status ? "WHERE status = $1" : "";
  const params = filter.status ? [filter.status] : [];
  return query<Order>(`SELECT id, customer_email AS "customerEmail", status, total_cents AS "totalCents", created_at AS "createdAt" FROM orders ${where} ORDER BY created_at DESC`, params);
}

export async function exportOrdersJson(filter: OrderFilter): Promise<string> {
  const orders = await listOrders(filter);
  return JSON.stringify(orders, null, 2);
}
