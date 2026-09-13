import { useEffect, useState } from "react";
import { exportUrl, fetchOrders } from "../api/orders";
import type { Order } from "../../../src/services/orders";

export function OrdersPage() {
  const [status, setStatus] = useState<string>("");
  const [orders, setOrders] = useState<Order[]>([]);

  useEffect(() => {
    fetchOrders(status || undefined).then(setOrders);
  }, [status]);

  return (
    <section>
      <header className="toolbar">
        <select value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="">All</option>
          <option value="pending">Pending</option>
          <option value="paid">Paid</option>
          <option value="refunded">Refunded</option>
        </select>
        <a className="button" href={exportUrl("json", status || undefined)} download>
          Export JSON
        </a>
      </header>
      <table>
        <tbody>
          {orders.map((o) => (
            <tr key={o.id}>
              <td>{o.id}</td>
              <td>{o.customerEmail}</td>
              <td>{o.status}</td>
              <td>{(o.totalCents / 100).toFixed(2)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
