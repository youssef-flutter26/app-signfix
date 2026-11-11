import { afterAll, beforeEach, describe, expect, it, vi } from "vitest";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const database = require("../../database.js");
const repository = require("./customerRepository.js");
const originalGetPool = database.getPool;
const queryMock = vi.fn();

afterAll(() => {
  database.getPool = originalGetPool;
});

describe("customer order listing", () => {
  beforeEach(() => {
    database.getPool = () => ({ query: queryMock });
    queryMock.mockReset();
    queryMock.mockImplementation(async (sql) => {
      if (sql.includes("SELECT c.id,c.user_id FROM customers")) {
        return { rows: [{ id: 12, user_id: 34 }] };
      }
      if (sql.includes("SELECT COUNT(*) AS total FROM orders")) {
        return { rows: [{ total: 1 }] };
      }
      if (sql.includes("SELECT o.order_no AS id")) {
        return {
          rows: [
            {
              id: "SB-ORD-20261020-0001",
              specifications: {},
              estimatedPrice: 66000,
              status: "pending_review",
            },
          ],
        };
      }
      throw new Error(`Unexpected query: ${sql}`);
    });
  });

  it("lists only orders with a successful, non-refunded payment", async () => {
    const result = await repository.orders(34, { status: "pending_review" });

    expect(result.data).toHaveLength(1);
    expect(result.total).toBe(1);

    const orderQueries = queryMock.mock.calls.filter(([sql]) =>
      sql.includes("FROM orders o"),
    );
    expect(orderQueries).toHaveLength(2);
    for (const [sql, params] of orderQueries) {
      expect(sql).toContain("EXISTS");
      expect(sql).toContain("p.status IN ('captured','partially_refunded')");
      expect(sql).toContain("p.amount>COALESCE(p.refunded_amount,0)");
      expect(sql).toContain("o.status=$2");
      expect(params.slice(0, 2)).toEqual([12, "pending_review"]);
      if (sql.includes("LIMIT")) {
        expect(params).toEqual([12, "pending_review", 20, 0]);
      } else {
        expect(params).toEqual([12, "pending_review"]);
      }
    }
  });
});
