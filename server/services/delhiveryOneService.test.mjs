import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const d1 = require("./delhiveryOneService");

const ENV = {
  D1_CLIENT_ID: "ucp-service-cli",
  D1_CLIENT_SECRET: "secret",
  D1_AUTH_URL: "https://ucp-auth.example.com/facelessvoid",
  D1_REALM: "ucp-test",
  D1_CLIENT_CMS: "cms::client::test",
  D1_MCP_URL: "https://mcp-client.example.com/mcp",
};

function useEnv() { Object.assign(process.env, ENV); }
function clearEnv() { for (const key of Object.keys(ENV)) delete process.env[key]; }

// Wraps a tool result the way the gateway returns it (SSE data line).
const sse = (payload) => `event: message\ndata: ${JSON.stringify(payload)}\n\n`;
const toolResult = (text) => sse({ jsonrpc: "2.0", id: 1, result: { content: [{ type: "text", text }] } });
const TOKEN = { access_token: "tok-1", expires_in: 600 };

describe("Delhivery One gateway", () => {
  // Vitest loads the project .env, which carries real D1_* values. Every case
  // starts unconfigured and opts in explicitly with useEnv().
  beforeEach(() => { clearEnv(); d1._resetCache(); });
  afterEach(() => { clearEnv(); d1._resetCache(); vi.unstubAllGlobals(); });

  it("reports missing configuration without any network call", async () => {
    const fetch = vi.fn();
    vi.stubGlobal("fetch", fetch);
    await expect(d1.getWallet()).rejects.toMatchObject({ status: 503, errorCode: "D1_NOT_CONFIGURED" });
    expect(fetch).not.toHaveBeenCalled();
  });

  it("mints one token and reuses it across tool calls", async () => {
    useEnv();
    const fetch = vi.fn()
      .mockResolvedValueOnce({ ok: true, status: 200, json: async () => TOKEN })
      .mockResolvedValue({ ok: true, status: 200, text: async () => toolResult('{"current_balance":500}') });
    vi.stubGlobal("fetch", fetch);
    await expect(d1.getWallet()).resolves.toEqual({ current_balance: 500 });
    await expect(d1.getWallet()).resolves.toEqual({ current_balance: 500 });
    // One token mint + two tool calls.
    expect(fetch).toHaveBeenCalledTimes(3);
    expect(fetch.mock.calls[0][0]).toBe(`${ENV.D1_AUTH_URL}/realms/${ENV.D1_REALM}/protocol/openid-connect/token`);
    expect(fetch.mock.calls[0][1].headers["Content-Type"]).toBe("application/x-www-form-urlencoded");
    expect(fetch.mock.calls[0][1].body).toContain("grant_type=client_credentials");
  });

  it("sends the bearer token and HQ client headers to the gateway", async () => {
    useEnv();
    const fetch = vi.fn()
      .mockResolvedValueOnce({ ok: true, status: 200, json: async () => TOKEN })
      .mockResolvedValue({ ok: true, status: 200, text: async () => toolResult("{}") });
    vi.stubGlobal("fetch", fetch);
    await d1.callTool("get-wallet-details", {});
    const [, options] = fetch.mock.calls[1];
    expect(options.headers.Authorization).toBe("Bearer tok-1");
    expect(options.headers["x-hq-client-id"]).toBe(ENV.D1_CLIENT_CMS);
    expect(JSON.parse(options.body)).toMatchObject({
      jsonrpc: "2.0",
      method: "tools/call",
      params: { name: "get-wallet-details", arguments: {} },
    });
  });

  it("maps credential rejection to D1_AUTH_FAILED", async () => {
    useEnv();
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false, status: 401 }));
    await expect(d1.getWallet()).rejects.toMatchObject({ errorCode: "D1_AUTH_FAILED" });
  });

  it("retries once with a fresh token when the gateway reports 401", async () => {
    useEnv();
    const fetch = vi.fn()
      .mockResolvedValueOnce({ ok: true, status: 200, json: async () => ({ access_token: "tok-old", expires_in: 600 }) })
      .mockResolvedValueOnce({ ok: false, status: 401 })
      .mockResolvedValueOnce({ ok: true, status: 200, json: async () => ({ access_token: "tok-new", expires_in: 600 }) })
      .mockResolvedValue({ ok: true, status: 200, text: async () => toolResult('{"current_balance":1}') });
    vi.stubGlobal("fetch", fetch);
    await expect(d1.getWallet()).resolves.toEqual({ current_balance: 1 });
    expect(fetch).toHaveBeenCalledTimes(4);
  });

  it("generates a request id per rate item and merges the batch", async () => {
    useEnv();
    const fetch = vi.fn()
      .mockResolvedValueOnce({ ok: true, status: 200, json: async () => TOKEN })
      .mockResolvedValue({ ok: true, status: 200, text: async () => toolResult('{"responses":[{"total_amount":42.01}]}') });
    vi.stubGlobal("fetch", fetch);
    const result = await d1.getRate([
      { origin_pin: "411014", destination_pin: "411014", shipping_mode: "SURFACE", weight: 500, weight_unit: "GM", payment_mode: "PREPAID" },
      { origin_pin: "411014", destination_pin: "411014", shipping_mode: "EXPRESS", weight: 500, weight_unit: "GM", payment_mode: "PREPAID" },
    ]);
    // One token mint + one gateway call per request.
    expect(fetch).toHaveBeenCalledTimes(3);
    const first = JSON.parse(fetch.mock.calls[1][1].body);
    const second = JSON.parse(fetch.mock.calls[2][1].body);
    expect(first.params.name).toBe("bulk-rate-calculator");
    expect(first.params.arguments).toMatchObject({ shipping_mode: "SURFACE", weight: 500 });
    expect(first.params.arguments.id).toMatch(/^SURFACE_\d+_0$/);
    expect(second.params.arguments.id).toMatch(/^EXPRESS_\d+_1$/);
    expect(result).toEqual({ responses: [{ total_amount: 42.01 }, { total_amount: 42.01 }] });
  });

  it("requires a ticket id for ticket lookup", async () => {
    useEnv();
    vi.stubGlobal("fetch", vi.fn());
    await expect(d1.getTicket()).rejects.toMatchObject({ status: 422 });
  });

  it("reports an unreachable gateway as D1_UNREACHABLE", async () => {
    useEnv();
    const fetch = vi.fn()
      .mockResolvedValueOnce({ ok: true, status: 200, json: async () => TOKEN })
      .mockRejectedValueOnce(Object.assign(new Error("boom"), { name: "TimeoutError" }));
    vi.stubGlobal("fetch", fetch);
    await expect(d1.getWallet()).rejects.toMatchObject({ status: 502, errorCode: "D1_UNREACHABLE" });
  });
});
