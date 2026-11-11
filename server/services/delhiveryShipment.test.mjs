import { describe, expect, it } from "vitest";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const delhivery = require("./delhiveryService");

describe("Delhivery shipment creation", () => {
  it("builds a CMU payload from order data", () => {
    const shipment = delhivery.buildShipmentPayload({
      orderNo: "SB-ORD-2026-782079",
      consignee: { name: "John Doe", address: "221B Baker Street", city: "Mumbai", state: "Maharashtra", pin: "400001", phone: "9876543210" },
      amount: 1500,
      product: "Acrylic sign board",
      quantity: 2,
      weightGm: 800,
    });
    expect(shipment).toMatchObject({
      order: "SB-ORD-2026-782079",
      pin: "400001",
      phone: "9876543210",
      payment_mode: "Prepaid",
      quantity: 2,
      total_amount: 1500,
    });
    expect(shipment.weight).toBeCloseTo(0.8);
    expect(shipment.shipping_mode).toMatch(/surface|express/i);
  });

  it("extracts the waybill from the real CMU response shapes", () => {
    expect(delhivery.extractWaybill({ success: true, packages: [{ waybill: "12345678901234", status: "Success" }] })).toBe("12345678901234");
    expect(delhivery.extractWaybill({ packages: [{ waybill: "  12345678901234 ", remarks: "Manifested" }] })).toBe("12345678901234");
    expect(delhivery.extractWaybill({ waybill: "12345678901234" })).toBe("12345678901234");
    expect(delhivery.extractWaybill({ success: true, packages: [] })).toBeNull();
    expect(delhivery.extractWaybill({ success: false, message: "Invalid pincode" })).toBeNull();
    expect(delhivery.extractWaybill(null)).toBeNull();
    // Never accept empty/garbage as a successful AWB
    expect(delhivery.extractWaybill({ packages: [{ waybill: "", status: "Success" }] })).toBeNull();
    expect(delhivery.extractWaybill({ packages: [{ status: "Success" }] })).toBeNull();
  });

  it("parses string and object addresses, flagging bad pin/phone", () => {
    const fromString = delhivery.parseConsignee({
      specifications: { address: "Shop 5, MG Road", product: "Board" },
      customerDetails: {},
      customer: { name: "John", mobile: "9876543210" },
      defaultAddress: { city: "Pune", state: "Maharashtra", pincode: "411014" },
    });
    expect(fromString).toMatchObject({ pin: "411014", phone: "9876543210", city: "Pune" });

    const bad = delhivery.parseConsignee({ specifications: {}, customerDetails: {}, customer: {}, defaultAddress: {} });
    expect(bad.pin).toBe("");
    expect(bad.phone).toBe("");
  });

  it("normalizes phone/pin variants", () => {
    const parsed = delhivery.parseConsignee({
      specifications: {},
      customerDetails: { phone: "+91-9876543210", pincode: "411 014" },
      customer: {},
      defaultAddress: {},
    });
    expect(parsed.phone).toBe("9876543210");
    expect(parsed.pin).toBe("411014");
  });

  it("builds the public tracking link shared by the API and the AWB email", () => {
    expect(delhivery.publicTrackingUrl("1234567890123")).toBe("https://www.delhivery.com/track-v2/package/1234567890123");
    expect(delhivery.publicTrackingUrl("a b/c")).toBe("https://www.delhivery.com/track-v2/package/a%20b%2Fc");
  });
});
