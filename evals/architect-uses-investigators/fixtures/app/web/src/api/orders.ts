import type { Order } from "../../../src/services/orders";

export async function fetchOrders(status?: string): Promise<Order[]> {
  const qs = status ? `?status=${encodeURIComponent(status)}` : "";
  const res = await fetch(`/api/orders${qs}`);
  if (!res.ok) throw new Error(`orders: ${res.status}`);
  return res.json();
}

export function exportUrl(format: "json", status?: string): string {
  const qs = status ? `?status=${encodeURIComponent(status)}` : "";
  return `/api/orders/export.${format}${qs}`;
}
