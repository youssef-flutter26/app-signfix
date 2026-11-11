# SignFix OTP Delivery

Technician registration OTPs are sent to the technician's email address through the configured SMTP provider. Customer signup does not require an OTP. WhatsApp credentials and an approved WhatsApp OTP template are not required for technician registration.

Configure these server-side environment variables:

```env
SMTP_HOST=...
SMTP_PORT=465
SMTP_SECURE=true
SMTP_USER=...
SMTP_PASS=...
SMTP_FROM=...
```

The technician registration OTP expires after 10 minutes and permits up to five verification attempts. A successful verification returns a short-lived signed token bound to the email address used for registration. WhatsApp Cloud API configuration may still be used by the separate order-notification features.

## Request Service / "Server error" fix

The customer location validation endpoint now catches asynchronous errors correctly and forwards them to the Express error handler. This prevents a missing service-area configuration from crashing the Node.js process.

If production has no active service areas, the API now returns a clear `503 SERVICE_AREA_NOT_CONFIGURED` response instead of terminating the server. Configure at least one active city under **Admin → Service areas** before opening customer service requests.

For temporary testing only, `SERVICE_AREA_ALLOW_EMPTY=true` can allow the development fallback in production. Do not leave this enabled when real service-area restrictions are required.

## Registration database compatibility

The server now performs an idempotent auth-schema compatibility check before registration. This repairs older SignFix databases that still have the original `users.status` constraint (`active/disabled`) or are missing `verified_at`, `updated_at`, `customer_addresses`, or `auth_otps`. This prevents those schema mismatches from surfacing as a generic registration 500.
