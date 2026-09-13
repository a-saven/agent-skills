import { describe, expect, it, vi } from "vitest";
import * as db from "../db/client";
import { exportOrdersJson } from "./orders";

describe("exportOrdersJson", () => {
  it("serialises the filtered rows", async () => {
    vi.spyOn(db, "query").mockResolvedValue([
      { id: "o1", customerEmail: "a@example.com", status: "paid", totalCents: 1200, createdAt: "2026-09-01T10:00:00Z" },
    ]);
    const body = await exportOrdersJson({ status: "paid" });
    expect(JSON.parse(body)).toHaveLength(1);
  });
});
