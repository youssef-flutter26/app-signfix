# Razorpay LIVE setup for SignFix

The project contains Razorpay order creation, checkout configuration, payment signature verification, retries, payment webhooks, and admin-authorized refunds. Customer payments are only enabled for a current quotation after the customer approves its final amount; estimates cannot be charged.

## cPanel environment variables

Set these in the Node.js application's environment variables (or the server `.env`, if your deployment uses one):

```env
PAYMENT_GATEWAY_ENABLED=true
PAYMENT_GATEWAY_PROVIDER=razorpay
RAZORPAY_KEY_ID=<LIVE KEY ID>
RAZORPAY_KEY_SECRET=<LIVE KEY SECRET>
RAZORPAY_WEBHOOK_SECRET=<SEPARATE WEBHOOK SECRET>
RAZORPAY_AUTO_CAPTURE=true
```

Do not put the LIVE secret into frontend code. Only `RAZORPAY_KEY_ID` is sent to the browser checkout; `RAZORPAY_KEY_SECRET` remains server-side.

## Webhook

Configure Razorpay webhook URL:

`https://YOUR-DOMAIN/api/payments/webhook`

Use the same value you set as `RAZORPAY_WEBHOOK_SECRET`. Subscribe to these events:

- `payment.authorized`
- `payment.captured`
- `payment.failed`
- `refund.created`
- `refund.processed`
- `refund.failed`

## Refunds

Only authenticated `admin` and `super_admin` users can request refunds. Submit a positive amount, reason, and unique idempotency key to:

`POST /api/admin/payments/:paymentId/refunds`

For example:

```json
{
  "amount": 500.00,
  "reason": "Customer order cancelled",
  "idempotencyKey": "refund-payment-123-1"
}
```

The refund endpoint reserves the refundable balance, calls Razorpay, and returns the provider's current refund status. `pending` refunds are finalized by refund webhooks. Use `GET /api/admin/payments/:paymentId/refunds` to inspect refund history. Reuse the same idempotency key only to retrieve the result of the original request; use a new key for a separate refund.

## Before going LIVE

1. Test with Razorpay Test Mode first.
2. Verify successful payment and failed payment flows.
3. Verify webhook delivery.
4. Test a partial refund and a full refund, and verify the corresponding `refund.*` webhooks update payment balances.
5. Switch to LIVE key ID and LIVE key secret.
6. Restart the Node.js application after changing environment variables.

## Security

Never commit live API secrets to Git or package them in a ZIP. If a live secret has been exposed in chat, logs, screenshots, Git, or a ZIP, rotate it in Razorpay and use the newly generated secret in cPanel.
