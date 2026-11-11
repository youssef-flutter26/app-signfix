# SignFix

Project file map: [docs/FOLDER_STRUCTURE.md](docs/FOLDER_STRUCTURE.md)

Technician mobile API integration: [docs/technician-api.md](docs/technician-api.md)

Sign board sales, service, maintenance and field-operations platform by **DL SSR INFOTECH**. The repository contains a responsive React operations console, a secured Node/Express REST API, and a MySQL relational schema. Customer and technician API contracts are retained for future mobile clients; native mobile applications are outside this build scope.

## Run locally

```bash
npm install
npm run dev       # starts React at :5173 and the API at :4000 together
npm run server    # starts only the API at http://localhost:4000
npm start         # production API/admin server (run npm run build first)
```

Demo accounts use `SignFix@123`: `customer@signfix.in`, `tech@signfix.in`, and `admin@signfix.in`.

## Business invariants

- Customer calculator values are always labelled **Estimated Price**.
- Only an admin-approved quotation is an official commercial amount.
- Asset QR tokens reveal no customer information without authenticated authorization.
- AI suggestions are concepts and cannot promise feasibility, price, or delivery dates.

## Architecture

- `src/api`, `src/context`, `src/hooks`: API client, authentication state and browser routing.
- `src/components`: reusable layouts and UI components.
- `src/pages/admin`: responsive operations console modules.
- `src/pages/customer`: mobile-first ordering, service, AI support and design-demo workflows.
- `src/pages/technician`: mobile-first field job dashboard and status workflow.
- `server/routes`: REST endpoint declarations grouped by domain.
- `server/controllers`: HTTP orchestration and validation boundaries.
- `server/middleware`: JWT authentication, role authorization, validation and errors.
- `server/database.js`: parameterized MySQL repository operations (through `server/mysqlPool.js`).
- `database`: MySQL schema and idempotent seeds.

Configure `JWT_SECRET`, database credentials, object storage, maps, FCM, and the LLM provider through environment variables before production deployment.

Customer mobile integration endpoints and payload flow are documented in [`docs/customer-api.md`](docs/customer-api.md).

## Brand assets

The supplied SignFix artwork is stored once as the text-based `branding/signfix-logo.svg` and reused by the admin favicon/header and both Flutter apps. The app-local and public asset entries are symbolic links, so Git reviews no longer contain unsupported binary image diffs. Native Android/iOS projects should use this SVG as their launcher-icon source during platform packaging.

## MySQL database setup

1. Copy `.env.example` to `.env` and change every secret.
2. Set `DATABASE_URL=mysql://USER:PASSWORD@HOST:3306/DATABASE` in `.env`.
3. Start the API with `npm run server`. On startup `server/migrate.js` applies
   `database/schema.mysql.sql` (missing tables only) and `database/seed.mysql.sql`
   (roles, permissions, notification templates). Outside production it also applies
   `database/seed.demo.mysql.sql` (demo users and catalog). Each file runs again only
   when its contents change; progress is recorded in `schema_migrations`.
4. Check `GET /api/health/db`: `database.mode` must be `mysql`.

`schema.mysql.sql` adds new tables to an existing database but does not alter
existing tables; for a new column append an `ALTER TABLE ... ADD COLUMN` line at the
end of the file (a column that already exists is skipped).
The code works on MySQL 8 and MariaDB 10.3+; PostgreSQL is no longer supported.

Never commit `.env` or use the demo credentials in production.

## Production deployment

The production Vite build is emitted to `dist` with host-rooted asset URLs.
Express serves the admin SPA at `/admin` (including deep-link fallbacks) and
the API below `/api`. When `MARKETING_WEB_ROOT` points to a separate Next.js
static export (or the sibling `signfix_web/out` build exists), Express serves
that website at `/`; without either, the previous
admin-at-root behavior remains available for standalone deployments. Vercel
proxies its `/api/*` requests to the Render service. See
[`docs/production-deployment.md`](docs/production-deployment.md) for Render,
Vercel, PM2, Passenger/cPanel, reverse-proxy, and validation details.

### Razorpay payments

Razorpay LIVE payment support is already implemented in this build. Enable it with:

```env
PAYMENT_GATEWAY_ENABLED=true
PAYMENT_GATEWAY_PROVIDER=razorpay
RAZORPAY_KEY_ID=<your-live-key-id>
RAZORPAY_KEY_SECRET=<your-live-key-secret>
RAZORPAY_WEBHOOK_SECRET=<your-webhook-secret>
RAZORPAY_AUTO_CAPTURE=true
```

**Security:** keep `RAZORPAY_KEY_SECRET` and `RAZORPAY_WEBHOOK_SECRET` only in cPanel/hosting environment variables. They are intentionally not stored in this ZIP. The webhook secret is separate from the API key secret and must be configured in Razorpay when creating the webhook.

Configure the webhook URL as `https://<your-host>/api/payments/webhook` and subscribe to `payment.authorized`, `payment.captured`, and `payment.failed`. Use Razorpay Test Mode while validating the workflow, then switch the environment values to LIVE when ready.
