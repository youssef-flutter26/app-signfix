import { afterEach, describe, expect, it, vi } from "vitest";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const delhivery = require("./delhiveryService");

const sample = {
  ShipmentData: [{ Shipment: {
    AWB: "1234567890", Origin: "Delhi", Destination: "Lucknow", ExpectedDeliveryDate: "2026-09-30T00:00:00",
    Status: { Status: "In Transit", StatusType: "UD", StatusLocation: "Kanpur_Hub", StatusDateTime: "2026-09-27T10:00:00" },
    Scans: [
      { ScanDetail: { Scan: "Manifested", ScanType: "UD", ScannedLocation: "Delhi", ScanDateTime: "2026-09-26T09:00:00" } },
      { ScanDetail: { Scan: "In Transit", ScanType: "UD", ScannedLocation: "Kanpur_Hub", ScanDateTime: "2026-09-27T10:00:00" } },
    ],
  } }],
};

describe("Delhivery tracking", () => {
  afterEach(() => { delete process.env.DELHIVERY_API_TOKEN; vi.unstubAllGlobals(); });

  it("maps courier statuses to stable stages", () => {
    expect(delhivery.stageOf("Manifested", "UD")).toBe("manifested");
    expect(delhivery.stageOf("In Transit", "UD")).toBe("in_transit");
    expect(delhivery.stageOf("Dispatched", "UD")).toBe("out_for_delivery");
    expect(delhivery.stageOf("Delivered", "DL")).toBe("delivered");
    expect(delhivery.stageOf("RTO", "DL")).toBe("returned");
    expect(delhivery.stageOf("Canceled", "CN")).toBe("cancelled");
  });

  it("fetches with the token header and normalizes scans newest first", async () => {
    process.env.DELHIVERY_API_TOKEN = "test-token";
    const fetch = vi.fn().mockResolvedValue({ ok: true, status: 200, json: async () => sample });
    vi.stubGlobal("fetch", fetch);
    const result = await delhivery.fetchTracking(["1234567890"]);
    expect(fetch.mock.calls[0][0]).toContain("waybill=1234567890");
    expect(fetch.mock.calls[0][1].headers.Authorization).toBe("Token test-token");
    const shipment = result.get("1234567890");
    expect(shipment).toMatchObject({ stage: "in_transit", statusLocation: "Kanpur_Hub", destination: "Lucknow" });
    expect(shipment.scans[0].status).toBe("In Transit");
  });

  it("reports missing configuration and rejected tokens", async () => {
    await expect(delhivery.fetchTracking(["1234567890"])).rejects.toMatchObject({ status: 503 });
    process.env.DELHIVERY_API_TOKEN = "bad";
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false, status: 401 }));
    await expect(delhivery.fetchTracking(["1234567890"])).rejects.toMatchObject({ errorCode: "DELHIVERY_AUTH_FAILED" });
  });
});
