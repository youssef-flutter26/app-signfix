# Delhivery order tracking

Orders can be linked to one or more Delhivery waybills (AWB). Tracking data is
fetched from the Delhivery tracking API (`/api/v1/packages/json/`) and cached in
`order_shipments` (MySQL). The table is created automatically on first use and
is also defined in `database/schema.mysql.sql`.

## Configuration

```env
DELHIVERY_API_TOKEN=<Delhivery API token>
DELHIVERY_BASE_URL=https://track.delhivery.com   # staging: https://staging-express.dltl.com
DELHIVERY_TRACKING_CACHE_MINUTES=15               # how old cached tracking may get before a refresh
DELHIVERY_TIMEOUT_MS=10000
# Shipment creation (auto AWB when an order is created):
DELHIVERY_PICKUP_LOCATION=<warehouse name registered in Delhivery>
DELHIVERY_SHIPPING_MODE=SURFACE                   # or EXPRESS
DELHIVERY_DEFAULT_WEIGHT_GM=500
DELHIVERY_AUTO_CREATE_SHIPMENT=true               # set false to only link AWBs manually
```

## Shipment creation (order -> AWB)

`POST /api/orders` keeps the same path, validation and DB insert. After the
order row is stored, the server best-effort calls Delhivery
`POST /api/cmu/create.json` (`format=json&data={"shipments":[{...}],
"pickup_location":{"name":"..."}}`) with the order number as the Delhivery
order reference, then saves the returned `packages[0].waybill` into
`order_shipments` plus the `orders.delhivery_awb` / `shipment_status` cache.
Idempotency: if the order already has a waybill, the existing AWB is reused
and no new Delhivery shipment is created. A Delhivery failure never deletes
the order; the response keeps the order with `delhiveryAwb: null` and
`shipmentStatus: FAILED` (retryable transport errors use `PENDING`).

Success response (additive fields only):

```json
{ "id": "SB-ORD-2026-782079", "delhiveryAwb": "12345678901234", "shipmentStatus": "CREATED" }
```

`GET /api/orders/:id/tracking` needs no new endpoint: with no AWB it returns
`{ "success": false, "message": "Delhivery shipment has not been created for this order" }`;
with an AWB it returns `{ "success": true, "orderId", "waybill", "status", "tracking": [...] }`
alongside the unchanged `shipments` array.

## Endpoints

All endpoints need `Authorization: Bearer <JWT>`. `:id` is the order number (e.g. `SB-ORD-...`).

| Method | Path | Roles | Purpose |
| --- | --- | --- | --- |
| POST | `/api/orders/:id/shipments` | super_admin, admin, sales_manager | Link a waybill: `{ "waybill": "1234567890123" }`. Syncs immediately and emails the AWB. |
| GET | `/api/orders/:id/tracking` | admins + owning customer | Order shipments with current status and scan history. Stale entries refresh automatically; staff can add `?refresh=true`. |
| DELETE | `/api/orders/:id/shipments/:waybill` | super_admin, admin, sales_manager | Unlink a waybill. |
| GET | `/api/orders/email-notifications/logs?limit=50` | super_admin, admin, sales_manager | AWB email delivery log (`pending`, `sent`, `failed`, `skipped`), recipient, provider id and error. |
| GET | `/api/shipments/track/:waybill` | super_admin, admin, sales_manager | Live lookup of any AWB (not stored). |
| POST | `/api/shipments/sync` | super_admin, admin, sales_manager | Refresh all undelivered, stale shipments (for a cron job). |

### Tracking response

```json
{
  "orderNo": "SB-ORD-20260926-0001",
  "orderStatus": "production",
  "shipments": [{
    "waybill": "1234567890123",
    "stage": "in_transit",
    "status": "In Transit",
    "statusType": "UD",
    "statusLocation": "Kanpur_Hub",
    "statusAt": "2026-09-27T10:00:00",
    "expectedDelivery": "2026-09-30T00:00:00",
    "origin": "Delhi",
    "destination": "Lucknow",
    "delivered": false,
    "scans": [{ "status": "In Transit", "statusType": "UD", "location": "Kanpur_Hub", "instructions": null, "at": "2026-09-27T10:00:00" }],
    "lastError": null,
    "lastSyncedAt": "2026-09-27T10:05:00.000Z",
    "trackingUrl": "https://www.delhivery.com/track-v2/package/1234567890123"
  }]
}
```

`stage` is one of `pending`, `manifested`, `in_transit`, `out_for_delivery`,
`delivered`, `returned`, `cancelled`. Use it for UI progress steps; `status` is
Delhivery's raw text. If Delhivery is unreachable, cached data is returned and
`lastError` explains why.

## AWB email to the customer

As soon as a waybill is linked to an order - auto-created by `POST /api/orders`
or attached later through `POST /api/orders/:id/shipments` - the customer who
placed the order is emailed the AWB together with the public Delhivery tracking
link (`trackingUrl` in the API response and the link in the email are built from
the same helper, so they cannot drift).

The email goes to `users.email` of the order's customer, not to any address in
the request body. It uses the same SMTP settings as the login/password-reset
OTPs (`SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER`, `SMTP_PASS`,
`SMTP_FROM`, `SMTP_TIMEOUT_MS`); if they are unset the attempt is recorded as
`skipped` and nothing else changes.

```env
SMTP_HOST=smtp.example.com
SMTP_PORT=465
SMTP_SECURE=true
SMTP_USER=orders@example.com
SMTP_PASS=...
SMTP_FROM=orders@example.com
```

Every attempt is written to `order_email_logs` (created on first use, also in
`database/schema.mysql.sql`) with `pending` / `sent` / `failed` / `skipped`, the
recipient, the provider message id and any error. Inspect it with
`GET /api/orders/email-notifications/logs`.

Delivery is best-effort and never affects the order:

- It is fire-and-forget, so SMTP latency does not delay the order response.
- A missing address, an unconfigured mailer or a provider outage leaves the
  order and the waybill untouched; the order is still created and returned.
- Retries are safe. A waybill whose email already went out is not sent again,
  while a previously `failed` or `skipped` attempt is sent again the next time
  that order's shipment step runs.
