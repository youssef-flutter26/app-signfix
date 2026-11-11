import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const emailOtp = require("./emailOtpService");
const nodemailer = require("nodemailer");

const ENV_KEYS = ["SMTP_HOST", "SMTP_PORT", "SMTP_SECURE", "SMTP_USER", "SMTP_PASS", "SMTP_FROM"];
function clearSmtpEnv() { for (const key of ENV_KEYS) delete process.env[key]; }
function useSmtpEnv() {
  Object.assign(process.env, {
    SMTP_HOST: "mail.example.com",
    SMTP_PORT: "465",
    SMTP_SECURE: "true",
    SMTP_USER: "hello@example.com",
    SMTP_PASS: "secret",
    SMTP_FROM: "hello@example.com",
  });
}

describe("Email OTP", () => {
  // Vitest loads the project .env, which carries real SMTP values. Every case
  // starts unconfigured and opts in explicitly with useSmtpEnv().
  beforeEach(() => { clearSmtpEnv(); emailOtp._resetTransporter(); vi.restoreAllMocks(); });
  afterEach(() => { clearSmtpEnv(); emailOtp._resetTransporter(); vi.restoreAllMocks(); });

  it("normalizes and validates email addresses", () => {
    expect(emailOtp.normalizeEmail("  Saurabh@Example.COM ")).toBe("saurabh@example.com");
    expect(emailOtp.normalizeEmail("not-an-email")).toBe("");
    expect(emailOtp.normalizeEmail("")).toBe("");
  });

  it("masks the local part of an email", () => {
    expect(emailOtp.maskEmail("saurabh@gmail.com")).toBe("sa*****@gmail.com");
    expect(emailOtp.maskEmail("ab@example.com")).toBe("ab*@example.com");
    expect(emailOtp.maskEmail("no-at-sign")).toBe("");
  });

  it("reports missing configuration without any network call", async () => {
    const spy = vi.spyOn(nodemailer, "createTransport");
    await expect(emailOtp.sendEmailOtp("a@example.com", "123456")).rejects.toMatchObject({
      status: 503,
      errorCode: "EMAIL_NOT_CONFIGURED",
    });
    expect(spy).not.toHaveBeenCalled();
  });

  it("rejects invalid recipients and OTPs", async () => {
    useSmtpEnv();
    await expect(emailOtp.sendEmailOtp("bad", "123456")).rejects.toMatchObject({ status: 422 });
    await expect(emailOtp.sendEmailOtp("a@example.com", "12")).rejects.toMatchObject({ errorCode: "EMAIL_OTP_INVALID" });
  });

  it("sends through the configured SMTP transport", async () => {
    useSmtpEnv();
    const sendMail = vi.fn().mockResolvedValue({ messageId: "test-id" });
    vi.spyOn(nodemailer, "createTransport").mockReturnValue({ sendMail });
    const result = await emailOtp.sendEmailOtp("user@example.com", "654321", "verify_registration");
    expect(result).toEqual({ recipient: "user@example.com", messageId: "test-id" });
    expect(nodemailer.createTransport).toHaveBeenCalledWith(expect.objectContaining({
      host: "mail.example.com",
      port: 465,
      secure: true,
      auth: { user: "hello@example.com", pass: "secret" },
    }));
    const mail = sendMail.mock.calls[0][0];
    expect(mail.to).toBe("user@example.com");
    expect(mail.subject).toContain("verification code");
    expect(mail.text).toContain("654321");
  });

  it("maps provider failures to EMAIL_PROVIDER_UNAVAILABLE", async () => {
    useSmtpEnv();
    vi.spyOn(nodemailer, "createTransport").mockReturnValue({
      sendMail: vi.fn().mockRejectedValue(new Error("Invalid login")),
    });
    await expect(emailOtp.sendEmailOtp("user@example.com", "654321")).rejects.toMatchObject({
      status: 502,
      errorCode: "EMAIL_PROVIDER_UNAVAILABLE",
    });
  });
});
