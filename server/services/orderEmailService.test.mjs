import { describe, it, expect, beforeEach } from "vitest";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const orderEmail = require("./orderEmailService");
const { toMysql } = require("../mysqlPool");

const normalizeEmail = (value) => {
  const email = String(value || "").trim().toLowerCase();
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ? email : "";
};

let sent;
let state;

// Minimal stand-in for the mysql2 wrapper. Every query the service issues is
// the DDL, the order lookup, the dedupe check, a log insert or a log update.
function makePool() {
  return {
    query: async (sql, params) => {
      if (/CREATE TABLE/.test(sql)) return { rows: [], rowCount: 0, insertId: 0 };
      if (/FROM orders o JOIN customers/.test(sql)) {
        return { rows: state.orderRow ? [state.orderRow] : [], rowCount: state.orderRow ? 1 : 0, insertId: 0 };
      }
      if (/SELECT 1 FROM order_email_logs/.test(sql)) {
        const found = state.logRows.filter((row) => row.order_id === params[0] && row.event_key === params[1] && row.status === "sent");
        return { rows: found, rowCount: found.length, insertId: 0 };
      }
      if (/INSERT INTO order_email_logs/.test(sql)) {
        const row = {
          id: state.logRows.length + 1,
          order_id: params[0],
          customer_user_id: params[1],
          event_key: params[2],
          recipient: params[3],
          subject: params[4],
          body: params[5],
          status: "pending",
        };
        state.logRows.push(row);
        return { rows: [], rowCount: 1, insertId: row.id };
      }
      if (/UPDATE order_email_logs/.test(sql)) {
        const target = state.logRows.find((row) => row.id === params[3]);
        if (target) Object.assign(target, { status: params[0], error_message: params[1], provider_message_id: params[2] });
        return { rows: [], rowCount: 1, insertId: 0 };
      }
      throw new Error(`Unexpected query: ${sql.slice(0, 60)}`);
    },
  };
}

beforeEach(() => {
  sent = [];
  state = {
    configured: true,
    sendError: null,
    orderRow: { id: 7, order_no: "SB-ORD-20260929-0001", user_id: 3, name: "Asha Rao", email: "asha@example.com", product: "Acrylic board" },
    logRows: [],
  };
  orderEmail._setDeps({
    isConfigured: () => state.configured,
    normalizeEmail,
    sendMail: async (message) => {
      if (state.sendError) throw state.sendError;
      sent.push(message);
      return { messageId: "<test-message-id>" };
    },
    pool: makePool,
    publicTrackingUrl: (awb) => `https://www.delhivery.com/track-v2/package/${awb}`,
  });
});

describe("queueAwbEmail", () => {
  it("emails the AWB with a Delhivery tracking link", async () => {
    const result = await orderEmail.queueAwbEmail(7, "1234567890123");

    expect(result).toMatchObject({ status: "sent", recipient: "asha@example.com", messageId: "<test-message-id>" });
    expect(sent).toHaveLength(1);
    expect(sent[0].to).toBe("asha@example.com");
    expect(sent[0].subject).toContain("SB-ORD-20260929-0001");
    expect(sent[0].subject).toContain("1234567890123");
    expect(sent[0].text).toContain("Tracking number (AWB): 1234567890123");
    expect(sent[0].text).toContain("https://www.delhivery.com/track-v2/package/1234567890123");
    expect(sent[0].html).toContain("https://www.delhivery.com/track-v2/package/1234567890123");
    expect(state.logRows[0]).toMatchObject({ status: "sent", provider_message_id: "<test-message-id>" });
  });

  it("escapes customer-supplied values in the HTML body", async () => {
    state.orderRow.name = '<img src=x onerror="alert(1)">';
    await orderEmail.queueAwbEmail(7, "1234567890123");

    expect(sent[0].html).not.toContain("<img src=x");
    expect(sent[0].html).toContain("&lt;img src=x");
  });

  it("skips without an SMTP configuration and records why", async () => {
    state.configured = false;
    const result = await orderEmail.queueAwbEmail(7, "1234567890123");

    expect(result).toMatchObject({ status: "skipped" });
    expect(sent).toHaveLength(0);
    expect(state.logRows[0].status).toBe("skipped");
    expect(state.logRows[0].error_message).toMatch(/not configured/);
  });

  it("skips when the customer has no usable email address", async () => {
    state.orderRow.email = "not-an-email";
    const result = await orderEmail.queueAwbEmail(7, "1234567890123");

    expect(result).toMatchObject({ status: "skipped" });
    expect(sent).toHaveLength(0);
    expect(state.logRows[0]).toMatchObject({ recipient: "", status: "skipped" });
  });

  it("records a provider failure without throwing", async () => {
    state.sendError = new Error("SMTP connection refused");
    const result = await orderEmail.queueAwbEmail(7, "1234567890123");

    expect(result).toMatchObject({ status: "failed" });
    expect(state.logRows[0].status).toBe("failed");
    expect(state.logRows[0].error_message).toMatch(/SMTP connection refused/);
  });

  it("does not re-send a waybill that already went out", async () => {
    await orderEmail.queueAwbEmail(7, "1234567890123");
    const second = await orderEmail.queueAwbEmail(7, "1234567890123");

    expect(second).toMatchObject({ status: "skipped", reason: "AWB email already sent" });
    expect(sent).toHaveLength(1);
  });

  it("retries a waybill whose first attempt failed", async () => {
    state.sendError = new Error("SMTP connection refused");
    await orderEmail.queueAwbEmail(7, "1234567890123");
    state.sendError = null;
    const retry = await orderEmail.queueAwbEmail(7, "1234567890123");

    expect(retry).toMatchObject({ status: "sent" });
    expect(sent).toHaveLength(1);
  });

  it("sends again when a different waybill is assigned", async () => {
    await orderEmail.queueAwbEmail(7, "1234567890123");
    await orderEmail.queueAwbEmail(7, "1234567890124");

    expect(sent.map((mail) => mail.subject)).toEqual([
      expect.stringContaining("1234567890123"),
      expect.stringContaining("1234567890124"),
    ]);
  });

  it("never throws when the database lookup fails", async () => {
    orderEmail._setDeps({
      isConfigured: () => true,
      normalizeEmail,
      sendMail: async () => ({ messageId: "x" }),
      pool: () => ({ query: async () => { throw new Error("ECONNREFUSED"); } }),
      publicTrackingUrl: () => "https://example.com",
    });
    await expect(orderEmail.queueAwbEmail(7, "1234567890123")).resolves.toMatchObject({ status: "failed" });
  });

  it("ignores an empty waybill", async () => {
    await expect(orderEmail.queueAwbEmail(7, "")).resolves.toMatchObject({ status: "skipped" });
    expect(state.logRows).toHaveLength(0);
  });

  // The order lookup embeds a MySQL JSON path, '$.product'. The pool rewrites
  // $1-style placeholders, so this guards that the path is not mangled into a
  // bind parameter and that the real placeholder still is one.
  it("keeps the $.product JSON path intact through placeholder rewriting", async () => {
    let seen = "";
    orderEmail._setDeps({
      isConfigured: () => false,
      normalizeEmail,
      sendMail: async () => ({ messageId: "x" }),
      publicTrackingUrl: () => "https://example.com",
      pool: () => ({
        query: async (sql, params) => {
          if (/FROM orders o JOIN customers/.test(sql)) {
            seen = toMysql(sql, params).sql;
            return { rows: [], rowCount: 0, insertId: 0 };
          }
          return { rows: [], rowCount: 0, insertId: 0 };
        },
      }),
    });
    await orderEmail.queueAwbEmail(7, "1234567890123");

    expect(seen).toContain("JSON_EXTRACT(o.specifications,'$.product')");
    expect(seen).toContain("WHERE o.id=?");
    expect(seen).not.toContain("$1");
  });
});

describe("awbMail", () => {
  it("renders order, item and tracking rows", () => {
    const mail = orderEmail.awbMail({ name: "Asha Rao", orderNo: "SB-ORD-1", waybill: "9998887776", productName: "Glow sign", trackingUrl: "https://example.com/t/9998887776" });

    expect(mail.subject).toBe("Your SignFix order SB-ORD-1 is on the way - AWB 9998887776");
    expect(mail.text).toContain("Item: Glow sign");
    expect(mail.text).toContain("Track your shipment: https://example.com/t/9998887776");
    expect(mail.html).toContain("https://example.com/t/9998887776");
  });

  it("falls back to a neutral greeting when the name is missing", () => {
    const mail = orderEmail.awbMail({ name: "", orderNo: "SB-ORD-1", waybill: "9998887776", productName: "", trackingUrl: "https://example.com/t/9998887776" });

    expect(mail.text).toContain("Hi,");
    expect(mail.text).not.toContain("Item:");
  });
});
