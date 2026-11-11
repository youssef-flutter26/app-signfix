# SignFix Final Deployment Checklist

## Technician API
- `/api/technician/*` and `/api/technicians/*` are supported.
- Base technician endpoints return API capability information.
- Technician requests still require a valid JWT and the `technician` role.

## Registration / OTP
- Customer signup does not require an OTP.
- Technician signup sends a verification OTP to the supplied email address through SMTP, then leaves the account pending admin approval.
- Configure `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER`, `SMTP_PASS`, and `SMTP_FROM` on the server.
- Keep SMTP credentials server-side; never put them in the frontend/mobile app.

## Payments
- Configure Razorpay keys only in server environment variables.
- Never commit a live Razorpay secret or expose it in the frontend/mobile bundle.

## Delhivery
- Delhivery credentials are server-only.
- Set `DELHIVERY_ENABLED=true` only after the Delhivery One API credentials/endpoints supplied by the account are configured.
- Persist shipment/waybill/tracking identifiers in the order integration layer before enabling automatic dispatch.

## cPanel
1. Use Node.js 20 or newer.
2. Set the application root to this project.
3. Set the startup file to `server/index.js`.
4. Configure `.env`/Node environment variables.
5. Run `npm ci`.
6. Run `npm run build`.
7. Run the database migration/schema setup.
8. Restart the Node application.
9. Test `GET /api/health`.
10. Test customer signup, technician email OTP, technician login, `/api/technician/`, `/api/technicians/`, orders and payments.
