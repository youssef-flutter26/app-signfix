import { afterEach, describe, expect, it } from "vitest";
import { createRequire } from "node:module";
import crypto from "node:crypto";
const require = createRequire(import.meta.url);
const razorpay = require("./razorpayService");

describe("Razorpay verification", () => {
  afterEach(() => {
    for (const key of [
      "PAYMENT_GATEWAY_ENABLED",
      "PAYMENT_GATEWAY_PROVIDER",
      "RAZORPAY_KEY_ID",
      "RAZORPAY_KEY_SECRET",
      "RAZORPAY_WEBHOOK_SECRET",
    ])
      delete process.env[key];
  });
  it("binds checkout signatures to the stored provider order", () => {
    Object.assign(process.env, {
      PAYMENT_GATEWAY_ENABLED: "true",
      PAYMENT_GATEWAY_PROVIDER: "razorpay",
      RAZORPAY_KEY_ID: "rzp_test_example",
      RAZORPAY_KEY_SECRET: "test-secret",
    });
    const signature = crypto
      .createHmac("sha256", "test-secret")
      .update("order_123|pay_456")
      .digest("hex");
    expect(
      razorpay.verifyCheckoutSignature("order_123", "pay_456", signature),
    ).toBe(true);
    expect(
      razorpay.verifyCheckoutSignature("order_changed", "pay_456", signature),
    ).toBe(false);
  });
  it("verifies the exact raw webhook body", () => {
    process.env.RAZORPAY_WEBHOOK_SECRET = "webhook-secret";
    const body = Buffer.from('{"event":"payment.captured"}'),
      signature = crypto
        .createHmac("sha256", "webhook-secret")
        .update(body)
        .digest("hex");
    expect(razorpay.verifyWebhook(body, signature)).toBe(true);
    expect(razorpay.verifyWebhook(Buffer.from("{}"), signature)).toBe(false);
  });
});

describe("Razorpay capture", () => {
  const originalFetch = global.fetch;
  afterEach(() => {
    global.fetch = originalFetch;
    for (const key of ["PAYMENT_GATEWAY_ENABLED", "PAYMENT_GATEWAY_PROVIDER", "RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET", "RAZORPAY_AUTO_CAPTURE"]) delete process.env[key];
  });
  const configure = () => Object.assign(process.env, { PAYMENT_GATEWAY_ENABLED: "true", PAYMENT_GATEWAY_PROVIDER: "razorpay", RAZORPAY_KEY_ID: "rzp_test_example", RAZORPAY_KEY_SECRET: "test-secret" });

  it("captures an authorized payment for its exact amount", async () => {
    configure();
    const calls = [];
    global.fetch = async (url, options) => { calls.push({ url, options }); return { ok: true, json: async () => ({ id: "pay_1", status: "captured" }) }; };
    await expect(razorpay.capturePayment("pay_1", 150000, "INR")).resolves.toMatchObject({ status: "captured" });
    expect(calls[0].url).toBe("https://api.razorpay.com/v1/payments/pay_1/capture");
    expect(JSON.parse(calls[0].options.body)).toEqual({ amount: 150000, currency: "INR" });
  });

  it("treats an already-captured payment as success", async () => {
    configure();
    global.fetch = async (url) => url.endsWith("/capture")
      ? { ok: false, json: async () => ({ error: { code: "BAD_REQUEST_ERROR", description: "This payment has already been captured" } }) }
      : { ok: true, json: async () => ({ id: "pay_1", status: "captured" }) };
    await expect(razorpay.capturePayment("pay_1", 150000, "INR")).resolves.toMatchObject({ status: "captured" });
  });

  it("can be switched off for accounts that auto-capture", () => {
    expect(razorpay.autoCaptureEnabled()).toBe(true);
    process.env.RAZORPAY_AUTO_CAPTURE = "false";
    expect(razorpay.autoCaptureEnabled()).toBe(false);
  });
});
