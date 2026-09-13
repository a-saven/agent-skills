import express from "express";
import { listOrders, exportOrdersJson } from "./services/orders";

const app = express();

app.get("/api/orders", async (req, res) => {
  const status = typeof req.query.status === "string" ? req.query.status : undefined;
  res.json(await listOrders({ status }));
});

app.get("/api/orders/export.json", async (req, res) => {
  const status = typeof req.query.status === "string" ? req.query.status : undefined;
  const body = await exportOrdersJson({ status });
  res.setHeader("Content-Disposition", 'attachment; filename="orders.json"');
  res.type("application/json").send(body);
});

app.listen(3000);
