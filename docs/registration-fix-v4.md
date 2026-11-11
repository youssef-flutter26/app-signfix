# Registration fix v4

This release addresses the recurring `Server error. Please try again later.` shown after **Complete Registration**.

### Root cause addressed

Older/partially migrated SignFix PostgreSQL databases can retain a `users.status` constraint that does not allow `pending_verification`, while the registration controller correctly creates accounts in `pending_verification`. The same databases can also be missing `verified_at`, `updated_at`, `customer_addresses`, or `auth_otps`.

### Fix

- Added an idempotent `ensureAuthSchema()` compatibility migration.
- It runs before the full migration and is also checked immediately before registration.
- It permits `pending_verification` and `deleted` user states.
- It creates the auth OTP table and required registration columns/tables when missing.
- Customer role creation is race-safe.
- Common PostgreSQL schema errors now return a useful 503 instead of a generic 500.
- WhatsApp OTP remains asynchronous, so Meta API latency does not block registration.

After deployment, restart the Node.js application once. The first request may perform the compatibility migration; subsequent registration requests use the cached result.
