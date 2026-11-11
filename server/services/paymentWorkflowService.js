const crypto = require("crypto");
const database = require("../database");
const razorpay = require("./razorpayService");
const { businessId } = require("../utils/ids");
const pool = () => database.getPool();

async function ownedPayment(userId, id, client = pool()) {
  const row = (
    await client.query(
      `SELECT p.*,q.quotation_no AS "quotationNo",q.final_amount AS "quotationAmount",o.id AS order_id,o.order_no AS "orderNo" FROM payments p LEFT JOIN quotations q ON q.id=p.quotation_id LEFT JOIN orders o ON o.id=COALESCE(p.order_id,q.order_id) JOIN customers c ON c.id=o.customer_id WHERE p.id=$1 AND c.user_id=$2`,
      [id, userId],
    )
  ).rows[0];
  if (!row)
    throw Object.assign(new Error("Payment not found"), { status: 404 });
  return row;
}

function publicPayment(row) {
  return {
    id: row.id,
    quotationNo: row.quotationNo,
    orderNo: row.orderNo,
    amount: row.amount,
    refundedAmount: row.refunded_amount || 0,
    currency: row.currency,
    status: row.status,
    reference: row.reference,
    type: row.payment_type,
    provider: row.provider,
    providerOrderId: row.provider_order_id,
    providerPaymentId: row.provider_payment_id,
    failureCode: row.failure_code,
    failureDescription: row.failure_description,
    attemptCount: row.attempt_count,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    checkout:
      row.provider_order_id &&
      ["pending", "created", "authorized"].includes(row.status)
        ? {
            keyId: process.env.RAZORPAY_KEY_ID,
            orderId: row.provider_order_id,
            amount: Math.round(Number(row.amount) * 100),
            currency: row.currency,
            name: process.env.COMPANY_NAME || "SignFix",
            description: row.quotationNo
              ? `Quotation ${row.quotationNo}`
              : `Order ${row.orderNo}`,
          }
        : null,
  };
}

async function initializeProvider(payment, userId) {
  try {
    const providerOrder = await razorpay.createOrder({
      amount: payment.amount,
      currency: payment.currency,
      receipt:
        `${payment.reference}-${Number(payment.attempt_count) + 1}`.slice(
          0,
          40,
        ),
      notes: {
        payment_reference: payment.reference,
        order: payment.orderNo,
        ...(payment.quotationNo ? { quotation: payment.quotationNo } : {}),
      },
    });
    await pool().query(
      `UPDATE payments SET provider_order_id=$2,status='pending',attempt_count=attempt_count+1,failure_code=NULL,failure_description=NULL,updated_at=NOW() WHERE id=$1 AND status IN ('created','initialization_failed','failed','cancelled')`,
      [payment.id, providerOrder.id],
    );
    const row = (await pool().query(`SELECT * FROM payments WHERE id=$1`, [payment.id])).rows[0];
    return publicPayment({ ...payment, ...row });
  } catch (error) {
    await pool().query(
      `UPDATE payments SET status='initialization_failed',attempt_count=attempt_count+1,failure_code=$2,failure_description=$3,updated_at=NOW() WHERE id=$1`,
      [payment.id, error.providerCode || "PROVIDER_UNAVAILABLE", error.message],
    );
    throw error;
  }
}

async function create(userId, data) {
  if (!razorpay.configured())
    throw Object.assign(new Error("Online payments are unavailable"), {
      status: 503,
    });
  const client = await pool().connect();
  let payment;
  let shouldInitialize = false;
  try {
    await client.query("BEGIN");
    const quote = (
      await client.query(
        `SELECT q.id,q.final_amount,q.valid_until,q.status,o.id AS order_id,o.order_no,c.payments_enabled FROM quotations q JOIN orders o ON o.id=q.order_id JOIN customers c ON c.id=o.customer_id WHERE q.quotation_no=$1 AND c.user_id=$2 FOR UPDATE`,
        [data.quotationNo, userId],
      )
    ).rows[0];
    if (
      !quote ||
      quote.status !== "approved" ||
      !quote.payments_enabled ||
      (quote.valid_until &&
        new Date(quote.valid_until).setHours(0, 0, 0, 0) <
          new Date(new Date().toDateString()).getTime())
    )
      throw Object.assign(
        new Error(
          "A current customer-approved quotation with payments enabled is required",
        ),
        { status: 409 },
      );

    const existing = (
      await client.query(
        `SELECT p.id FROM payments p JOIN orders o ON o.id=COALESCE(p.order_id,$2) JOIN customers c ON c.id=o.customer_id WHERE p.idempotency_key=$1 AND c.user_id=$3`,
        [data.idempotencyKey, quote.order_id, userId],
      )
    ).rows[0];
    if (existing) {
      payment = await ownedPayment(userId, existing.id, client);
      if (
        payment.quotationNo !== data.quotationNo ||
        payment.payment_type !== data.type
      )
        throw Object.assign(
          new Error("This idempotency key was already used for a different payment"),
          { status: 409 },
        );
      await client.query("COMMIT");
      shouldInitialize = !payment.provider_order_id;
    } else {
      const paid = Number(
        (
          await client.query(
            `SELECT COALESCE(SUM(amount-refunded_amount),0) total FROM payments WHERE (quotation_id=$1 OR order_id=$2) AND status IN ('captured','partially_refunded','refunded')`,
            [quote.id, quote.order_id],
          )
        ).rows[0].total,
      );
      const remaining = Math.max(
        0,
        Number((Number(quote.final_amount) - paid).toFixed(2)),
      );
    if (remaining <= 0)
      throw Object.assign(new Error("Quotation is already fully paid"), {
        status: 409,
      });

      const requested =
        data.type === "advance"
          ? Number((Number(quote.final_amount) * 0.25).toFixed(2))
          : remaining;
      const amount =
        data.type === "advance"
          ? Math.min(Math.max(0, requested - paid), remaining)
          : remaining;
      if (amount < 0.01)
        throw Object.assign(
          new Error("The advance payment has already been satisfied"),
          { status: 409 },
        );

    const active = (
      await client.query(
          `SELECT id,payment_type FROM payments WHERE quotation_id=$1 AND status IN ('created','pending','authorized') ORDER BY id DESC LIMIT 1`,
          [quote.id],
      )
    ).rows[0];
    if (active) {
      payment = await ownedPayment(userId, active.id, client);
        if (active.payment_type !== data.type)
          throw Object.assign(
            new Error("Another payment for this quotation is still in progress"),
            { status: 409 },
          );
      await client.query("COMMIT");
        shouldInitialize = !payment.provider_order_id;
      } else {
    const paymentInsert = await client.query(
      `INSERT INTO payments(quotation_id,order_id,amount,status,reference,payment_type,provider,currency,idempotency_key,metadata) VALUES($1,$2,$3,'created',$4,$5,'razorpay','INR',$6,$7)`,
      [
        quote.id,
        quote.order_id,
        amount,
        businessId("PAY"),
        data.type,
        data.idempotencyKey,
        JSON.stringify({ officialQuotationAmount: quote.final_amount }),
      ],
    );
    payment = (await client.query(`SELECT * FROM payments WHERE id=$1`, [paymentInsert.insertId])).rows[0];
    payment.quotationNo = data.quotationNo;
    payment.orderNo = quote.order_no;
    payment.order_id = quote.order_id;
    await client.query(
      `INSERT INTO audit_logs(user_id,action,entity_type,entity_id,metadata) VALUES($1,'payment.created','payment',$2,$3)`,
      [
        userId,
        payment.id,
        JSON.stringify({
          reference: payment.reference,
          quotationNo: data.quotationNo,
          amount,
            officialQuotationAmount: quote.final_amount,
            paidAmount: paid,
        }),
      ],
    );
    await client.query("COMMIT");
        shouldInitialize = true;
      }
    }
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
  return payment.provider_order_id && !shouldInitialize
    ? publicPayment(payment)
    : initializeProvider(payment, userId);
}

async function createForOrder(userId, data) {
  if (!razorpay.configured())
    throw Object.assign(new Error("Online payments are unavailable"), {
      status: 503,
    });

  const client = await pool().connect();
  let payment;
  let shouldInitialize = false;
  try {
    await client.query("BEGIN");
    const order = (
      await client.query(
        `SELECT o.id,o.order_no,o.estimated_price,o.status FROM orders o JOIN customers c ON c.id=o.customer_id WHERE o.order_no=$1 AND c.user_id=$2 FOR UPDATE`,
        [data.orderNo, userId],
      )
    ).rows[0];
    if (!order)
      throw Object.assign(new Error("Order not found"), { status: 404 });
    if (["cancelled", "completed"].includes(order.status))
      throw Object.assign(
        new Error("Payment is unavailable for this order"),
        { status: 409 },
      );

    const estimate = Number(order.estimated_price);
    if (!Number.isFinite(estimate) || estimate <= 0)
      throw Object.assign(
        new Error("This order does not have a payable estimated amount"),
        { status: 409 },
      );

    const existingByKey = (
      await client.query(
        `SELECT p.id,p.payment_type FROM payments p LEFT JOIN quotations q ON q.id=p.quotation_id JOIN orders o ON o.id=COALESCE(p.order_id,q.order_id) JOIN customers c ON c.id=o.customer_id WHERE p.idempotency_key=$1 AND c.user_id=$2`,
        [data.idempotencyKey, userId],
      )
    ).rows[0];
    if (existingByKey) {
      payment = await ownedPayment(userId, existingByKey.id, client);
      if (
        payment.orderNo !== data.orderNo ||
        payment.payment_type !== data.type
      )
        throw Object.assign(
          new Error("This idempotency key was already used for a different payment"),
          { status: 409 },
        );
      await client.query("COMMIT");
      shouldInitialize = !payment.provider_order_id;
    } else {
      const paid = Number(
        (
          await client.query(
            `SELECT COALESCE(SUM(p.amount-COALESCE(p.refunded_amount,0)),0) total FROM payments p LEFT JOIN quotations q ON q.id=p.quotation_id WHERE (p.order_id=$1 OR q.order_id=$1) AND p.status IN ('captured','partially_refunded','refunded')`,
            [order.id],
          )
        ).rows[0].total,
      );
      const remaining = Math.max(0, Number((estimate - paid).toFixed(2)));
      if (remaining <= 0)
        throw Object.assign(new Error("This order is already fully paid"), {
          status: 409,
        });

      const active = (
        await client.query(
          `SELECT p.id,p.payment_type,p.status FROM payments p LEFT JOIN quotations q ON q.id=p.quotation_id WHERE (p.order_id=$1 OR q.order_id=$1) AND p.status IN ('created','pending','authorized') ORDER BY p.id DESC LIMIT 1`,
          [order.id],
        )
      ).rows[0];
      if (active) {
        if (active.status === "authorized")
          throw Object.assign(
            new Error("A payment is already authorized for this order. Check payment status before retrying."),
            { status: 409 },
          );
        if (active.payment_type !== data.type)
          throw Object.assign(
            new Error("Another payment for this order is still in progress"),
            { status: 409 },
          );
        payment = await ownedPayment(userId, active.id, client);
        await client.query("COMMIT");
        shouldInitialize = !payment.provider_order_id;
      } else {
        const requested =
          data.type === "advance"
            ? Number((estimate * 0.25).toFixed(2))
            : remaining;
        const amount =
          data.type === "advance"
            ? Math.min(Math.max(0, requested - paid), remaining)
            : remaining;
        if (amount < 0.01)
          throw Object.assign(
            new Error("The required advance payment has already been paid"),
            { status: 409 },
          );

        const inserted = await client.query(
          `INSERT INTO payments(quotation_id,order_id,amount,status,reference,payment_type,provider,currency,idempotency_key,metadata) VALUES(NULL,$1,$2,'created',$3,$4,'razorpay','INR',$5,$6)`,
          [
            order.id,
            amount,
            businessId("PAY"),
            data.type,
            data.idempotencyKey,
            JSON.stringify({
              orderEstimate: estimate,
              paymentScope: "order_estimate",
              paidAmount: paid,
            }),
          ],
        );
        payment = (
          await client.query(`SELECT * FROM payments WHERE id=$1`, [
            inserted.insertId,
          ])
        ).rows[0];
        payment.orderNo = order.order_no;
        payment.order_id = order.id;
        await client.query(
          `INSERT INTO audit_logs(user_id,action,entity_type,entity_id,metadata) VALUES($1,'payment.created','payment',$2,$3)`,
          [
            userId,
            payment.id,
            JSON.stringify({
              reference: payment.reference,
              orderNo: order.order_no,
              amount,
              estimatedAmount: estimate,
              paidAmount: paid,
              paymentType: data.type,
            }),
          ],
        );
        await client.query("COMMIT");
        shouldInitialize = true;
      }
    }
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }

  return payment.provider_order_id && !shouldInitialize
    ? publicPayment(payment)
    : initializeProvider(payment, userId);
}

async function retry(userId, id) {
  const payment = await ownedPayment(userId, id);
  if (
    !["created", "initialization_failed", "failed", "cancelled"].includes(
      payment.status,
    )
  )
    throw Object.assign(
      new Error(
        "Only uninitialized, failed, or cancelled payments can be retried",
      ),
      { status: 409 },
    );
  const result = payment.orderNo
    ? await createForOrder(userId, {
        orderNo: payment.orderNo,
        type: payment.payment_type,
        idempotencyKey: crypto.randomUUID(),
      })
    : await create(userId, {
        quotationNo: payment.quotationNo,
        type: payment.payment_type,
        idempotencyKey: crypto.randomUUID(),
      });
  await pool().query(
    `INSERT INTO audit_logs(user_id,action,entity_type,entity_id,metadata) VALUES($1,'payment.retried','payment',$2,$3)`,
    [
      userId,
      id,
      JSON.stringify({
        reference: payment.reference,
        replacementPaymentId: result.id,
      }),
    ],
  );
  return result;
}
async function cancel(userId, id) {
  const target = (
    await pool().query(
      `SELECT p.* FROM payments p LEFT JOIN quotations q ON q.id=p.quotation_id JOIN orders o ON o.id=COALESCE(p.order_id,q.order_id) JOIN customers c ON c.id=o.customer_id WHERE p.id=$1 AND c.user_id=$2 AND p.status IN ('created','initialization_failed') AND p.provider_order_id IS NULL`,
      [id, userId],
    )
  ).rows[0];
  if (!target)
    throw Object.assign(new Error("Payment cannot be cancelled"), {
      status: 409,
    });
  await pool().query(
    `UPDATE payments SET status='cancelled',updated_at=NOW() WHERE id=$1 AND status IN ('created','initialization_failed') AND provider_order_id IS NULL`,
    [id],
  );
  const row = { ...target, status: "cancelled" };
  await pool().query(
    `INSERT INTO audit_logs(user_id,action,entity_type,entity_id,metadata) VALUES($1,'payment.cancelled','payment',$2,$3)`,
    [userId, id, JSON.stringify({ reference: row.reference })],
  );
  return publicPayment({ ...(await ownedPayment(userId, id)), ...row });
}

async function applyVerifiedState(
  client,
  paymentId,
  state,
  providerPaymentId,
  failure = {},
) {
  const current = (
    await client.query(
      `SELECT p.id,p.quotation_id,p.order_id,p.status,p.amount,p.currency,q.final_amount,o.id AS order_id FROM payments p LEFT JOIN quotations q ON q.id=p.quotation_id LEFT JOIN orders o ON o.id=COALESCE(p.order_id,q.order_id) WHERE p.id=$1 FOR UPDATE`,
      [paymentId],
    )
  ).rows[0];
  if (!current) return null;
  const rank = {
    created: 0,
    pending: 1,
    failed: 1,
    cancelled: 1,
    authorized: 2,
    captured: 3,
    partially_refunded: 4,
    refunded: 5,
  };
  if (
    (rank[state] ?? 0) < (rank[current.status] ?? 0) &&
    current.status !== "failed"
  )
    return current;
  await client.query(
    `UPDATE payments SET status=$2,provider_payment_id=COALESCE($3,provider_payment_id),failure_code=$4,failure_description=$5,verified_at=NOW(),captured_at=CASE WHEN $2='captured' THEN COALESCE(captured_at,NOW()) ELSE captured_at END,updated_at=NOW() WHERE id=$1`,
    [
      paymentId,
      state,
      providerPaymentId,
      failure.code || null,
      failure.description || null,
    ],
  );
  if (state === "captured" && current.quotation_id) {
    const total = Number(
      (
        await client.query(
          `SELECT COALESCE(SUM(amount-refunded_amount),0) total FROM payments WHERE (quotation_id=$1 OR order_id=$2) AND status IN ('captured','partially_refunded','refunded')`,
          [current.quotation_id, current.order_id],
        )
      ).rows[0].total,
    );
    if (total >= Number(current.final_amount))
      await client.query(
        `UPDATE orders SET status=CASE WHEN status='approved' THEN 'production' ELSE status END,updated_at=NOW() WHERE id=$1`,
        [current.order_id],
      );
  }
  if (state === "captured" && current.order_id) {
    const orderRow = (
      await client.query(
        `SELECT id, estimated_price, status FROM orders WHERE id=$1`,
        [current.order_id],
      )
    ).rows[0];
    if (orderRow) {
      await client.query(
        `UPDATE orders SET status=CASE WHEN status IN ('under_review','pending','approved') THEN 'in_production' ELSE status END, updated_at=NOW() WHERE id=$1`,
        [current.order_id],
      );
      await client.query(
        `INSERT INTO order_status_history(order_id,status,notes,created_by) VALUES($1,'in_production','Payment verified and order confirmed by gateway',NULL)`,
        [current.order_id],
      );
    }
    await database.creditOrderCashback(client, current.order_id);
  }
  if (state === "captured" || state === "failed") {
    const meta = (
      await client.query(
        `SELECT q.quotation_no,o.order_no,c.user_id,p.amount FROM payments p LEFT JOIN quotations q ON q.id=p.quotation_id JOIN orders o ON o.id=COALESCE(p.order_id,q.order_id) JOIN customers c ON c.id=o.customer_id WHERE p.id=$1`,
        [paymentId],
      )
    ).rows[0];
    if (meta?.user_id) {
      const isSuccess = state === "captured";
      require("./notificationService").sendEvent(
        meta.user_id,
        isSuccess ? "payment.success" : "payment.failed",
        isSuccess ? "Payment Successful" : "Payment Failed",
        isSuccess
          ? `Payment of INR ${meta.amount} for ${meta.quotation_no ? `quotation ${meta.quotation_no}` : `order ${meta.order_no}`} was successful.`
          : `Payment of INR ${meta.amount} for ${meta.quotation_no ? `quotation ${meta.quotation_no}` : `order ${meta.order_no}`} failed.`,
        { paymentId, quotationNo: meta.quotation_no, state },
      ).catch(() => {});
    }
  }
  return current;
}

async function confirm(userId, id, data) {
  const payment = await ownedPayment(userId, id);
  if (
    payment.provider_order_id !== data.razorpayOrderId ||
    !razorpay.verifyCheckoutSignature(
      payment.provider_order_id,
      data.razorpayPaymentId,
      data.razorpaySignature,
    )
  )
    throw Object.assign(new Error("Invalid payment signature"), {
      status: 401,
    });
  let remote = await razorpay.fetchPayment(data.razorpayPaymentId);
  if (
    remote.order_id === payment.provider_order_id &&
    Number(remote.amount) === Math.round(Number(payment.amount) * 100) &&
    remote.status === "authorized" &&
    razorpay.autoCaptureEnabled()
  )
    remote = await razorpay.capturePayment(remote.id, remote.amount, remote.currency);
  if (
    remote.order_id !== payment.provider_order_id ||
    Number(remote.amount) !== Math.round(Number(payment.amount) * 100) ||
    remote.currency !== payment.currency
  )
    throw Object.assign(
      new Error("Payment provider details do not match this transaction"),
      { status: 409 },
    );
  const state =
    remote.status === "captured"
      ? "captured"
      : remote.status === "authorized"
        ? "authorized"
        : remote.status === "failed"
          ? "failed"
          : "pending";
  const client = await pool().connect();
  try {
    await client.query("BEGIN");
    await applyVerifiedState(client, id, state, remote.id, {
      code: remote.error_code,
      description: remote.error_description,
    });
    await client.query(
      `INSERT INTO audit_logs(user_id,action,entity_type,entity_id,metadata) VALUES($1,$2,'payment',$3,$4)`,
      [
        userId,
        `payment.${state}`,
        id,
        JSON.stringify({
          reference: payment.reference,
          providerPaymentId: remote.id,
        }),
      ],
    );
    await client.query("COMMIT");
  } catch (e) {
    await client.query("ROLLBACK");
    throw e;
  } finally {
    client.release();
  }
  return publicPayment(await ownedPayment(userId, id));
}
async function reportFailure(userId, id, data) {
  const payment = await ownedPayment(userId, id);
  const client = await pool().connect();
  try {
    await client.query("BEGIN");
    await client.query(
      `INSERT INTO audit_logs(user_id,action,entity_type,entity_id,metadata) VALUES($1,'payment.reported_failed','payment',$2,$3)`,
      [
        userId,
        id,
        JSON.stringify({
          reference: payment.reference,
          currentStatus: payment.status,
          code: data.code || null,
          description: data.description || null,
          source: data.source || null,
          step: data.step || null,
          method: data.method || null,
        }),
      ],
    );
    await client.query("COMMIT");
  } catch (e) {
    await client.query("ROLLBACK");
    throw e;
  } finally {
    client.release();
  }
  return publicPayment(await ownedPayment(userId, id));
}
async function get(userId, id) {
  return publicPayment(await ownedPayment(userId, id));
}
async function list(userId) {
  const rows = (
    await pool().query(
      `SELECT p.*,q.quotation_no AS "quotationNo",o.order_no AS "orderNo" FROM payments p LEFT JOIN quotations q ON q.id=p.quotation_id JOIN orders o ON o.id=COALESCE(p.order_id,q.order_id) JOIN customers c ON c.id=o.customer_id WHERE c.user_id=$1 ORDER BY p.id DESC`,
      [userId],
    )
  ).rows;
  return { data: rows.map(publicPayment) };
}

function refundDto(row) {
  return {
    id: row.id,
    paymentId: row.payment_id,
    amount: row.amount,
    status: row.status,
    reference: row.reference,
    providerRefundId: row.provider_refund_id,
    reason: row.reason,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

async function applyRefundState(client, refundId, state, providerRefundId, details) {
  const refund = (
    await client.query(
      `SELECT id,payment_id,status,amount,metadata FROM payment_refunds WHERE id=$1 FOR UPDATE`,
      [refundId],
    )
  ).rows[0];
  if (!refund) throw Object.assign(new Error("Refund not found"), { status: 404 });

  if (["processed", "failed"].includes(refund.status) && refund.status !== state)
    return refund;
  const metadata =
    refund.metadata && typeof refund.metadata === "object"
      ? refund.metadata
      : refund.metadata
        ? JSON.parse(refund.metadata)
        : {};
  await client.query(
    `UPDATE payment_refunds SET status=$2,provider_refund_id=COALESCE($3,provider_refund_id),metadata=$4,updated_at=NOW() WHERE id=$1`,
    [
      refundId,
      state,
      providerRefundId || null,
      JSON.stringify({ ...metadata, provider: details || null }),
    ],
  );

  const payment = (
    await client.query(
      `SELECT id,amount FROM payments WHERE id=$1 FOR UPDATE`,
      [refund.payment_id],
    )
  ).rows[0];
  const refunded = Number(
    (
      await client.query(
        `SELECT COALESCE(SUM(amount),0) total FROM payment_refunds WHERE payment_id=$1 AND status='processed'`,
        [refund.payment_id],
      )
    ).rows[0].total,
  );
  if (refunded > Number(payment.amount) + 0.005)
    throw Object.assign(new Error("Processed refunds exceed the captured payment"), {
      status: 409,
    });
  await client.query(
    `UPDATE payments SET refunded_amount=$2,status=CASE WHEN $2<=0 THEN 'captured' WHEN $2>=amount-0.005 THEN 'refunded' ELSE 'partially_refunded' END,updated_at=NOW() WHERE id=$1`,
    [refund.payment_id, refunded],
  );
  return { ...refund, status: state, provider_refund_id: providerRefundId || refund.provider_refund_id };
}

async function createRefund(paymentId, input, adminUserId) {
  if (!razorpay.configured())
    throw Object.assign(new Error("Online refunds are unavailable"), {
      status: 503,
    });
  const client = await pool().connect();
  let refund;
  try {
    await client.query("BEGIN");
    const payment = (
      await client.query(
        `SELECT id,amount,refunded_amount,status,provider,provider_payment_id FROM payments WHERE id=$1 FOR UPDATE`,
        [paymentId],
      )
    ).rows[0];
    if (!payment)
      throw Object.assign(new Error("Payment not found"), { status: 404 });
    const existing = (
      await client.query(
        `SELECT * FROM payment_refunds WHERE idempotency_key=$1`,
        [input.idempotencyKey],
      )
    ).rows[0];
    if (existing) {
      if (
        Number(existing.payment_id) !== Number(paymentId) ||
        Number(existing.amount) !== Number(input.amount) ||
        existing.reason !== input.reason
      )
        throw Object.assign(
          new Error("This idempotency key was already used for a different refund"),
          { status: 409 },
        );
      refund = existing;
      await client.query("COMMIT");
      return refundDto(refund);
    }
    if (
      payment.provider !== "razorpay" ||
      !payment.provider_payment_id ||
      !["captured", "partially_refunded"].includes(payment.status)
    )
      throw Object.assign(
        new Error("Only captured Razorpay payments can be refunded"),
        { status: 409 },
      );

    const reserved = Number(
      (
        await client.query(
          `SELECT COALESCE(SUM(amount),0) total FROM payment_refunds WHERE payment_id=$1 AND status IN ('initializing','pending')`,
          [paymentId],
        )
      ).rows[0].total,
    );
    const refundable = Number(
      (
        Number(payment.amount) -
        Number(payment.refunded_amount || 0) -
        reserved
      ).toFixed(2),
    );
    if (input.amount > refundable + 0.005)
      throw Object.assign(
        new Error(`Refund amount exceeds the remaining refundable balance (${refundable.toFixed(2)})`),
        { status: 409 },
      );

    const inserted = await client.query(
      `INSERT INTO payment_refunds(payment_id,amount,status,reference,idempotency_key,reason,created_by,metadata) VALUES($1,$2,'initializing',$3,$4,$5,$6,$7)`,
      [
        paymentId,
        input.amount,
        businessId("REF"),
        input.idempotencyKey,
        input.reason,
        adminUserId,
        JSON.stringify({ provider: null }),
      ],
    );
    refund = (
      await client.query(`SELECT * FROM payment_refunds WHERE id=$1`, [
        inserted.insertId,
      ])
    ).rows[0];
    await client.query(
      `INSERT INTO audit_logs(user_id,action,entity_type,entity_id,metadata) VALUES($1,'payment.refund_requested','payment',$2,$3)`,
      [
        adminUserId,
        paymentId,
        JSON.stringify({ refundReference: refund.reference, amount: input.amount }),
      ],
    );
    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }

  try {
    const providerRefund = await razorpay.createRefund(
      (
        await pool().query(`SELECT provider_payment_id FROM payments WHERE id=$1`, [
          paymentId,
        ])
      ).rows[0].provider_payment_id,
      {
        amount: Math.round(Number(refund.amount) * 100),
        notes: {
          signfix_refund_reference: refund.reference,
          signfix_payment_id: String(paymentId),
        },
      },
    );
    const state =
      providerRefund.status === "processed"
        ? "processed"
        : providerRefund.status === "failed"
          ? "failed"
          : "pending";
    const updateClient = await pool().connect();
    try {
      await updateClient.query("BEGIN");
      await applyRefundState(
        updateClient,
        refund.id,
        state,
        providerRefund.id,
        providerRefund,
      );
      await updateClient.query(
        `INSERT INTO audit_logs(user_id,action,entity_type,entity_id,metadata) VALUES($1,$2,'payment',$3,$4)`,
        [
          adminUserId,
          `payment.refund_${state}`,
          paymentId,
          JSON.stringify({ refundReference: refund.reference, providerRefundId: providerRefund.id }),
        ],
      );
      await updateClient.query("COMMIT");
    } catch (error) {
      await updateClient.query("ROLLBACK");
      throw error;
    } finally {
      updateClient.release();
    }
    return refundDto(
      (
        await pool().query(`SELECT * FROM payment_refunds WHERE id=$1`, [
          refund.id,
        ])
      ).rows[0],
    );
  } catch (error) {
    if (error.status === 502 && error.providerCode) {
      await pool().query(
        `UPDATE payment_refunds SET status='failed',metadata=$2,updated_at=NOW() WHERE id=$1 AND status='initializing'`,
        [
          refund.id,
          JSON.stringify({ providerError: error.providerCode, message: error.message }),
        ],
      );
    } else {
      await pool().query(
        `UPDATE payment_refunds SET status='pending',updated_at=NOW() WHERE id=$1 AND status='initializing'`,
        [refund.id],
      );
    }
    throw error;
  }
}

async function listRefunds(paymentId) {
  const payment = (
    await pool().query(`SELECT id FROM payments WHERE id=$1`, [paymentId])
  ).rows[0];
  if (!payment)
    throw Object.assign(new Error("Payment not found"), { status: 404 });
  const rows = (
    await pool().query(
      `SELECT * FROM payment_refunds WHERE payment_id=$1 ORDER BY id DESC`,
      [paymentId],
    )
  ).rows;
  return { data: rows.map(refundDto) };
}

async function webhook(rawBody, headers, body) {
  if (!razorpay.verifyWebhook(rawBody, headers["x-razorpay-signature"]))
    throw Object.assign(new Error("Invalid webhook signature"), {
      status: 401,
    });
  const eventId = headers["x-razorpay-event-id"];
  if (!eventId)
    throw Object.assign(new Error("Missing Razorpay event identifier"), {
      status: 422,
    });
  const event = body.event;
  const isPaymentEvent = [
    "payment.authorized",
    "payment.captured",
    "payment.failed",
  ].includes(event);
  const isRefundEvent = [
    "refund.created",
    "refund.processed",
    "refund.failed",
  ].includes(event);
  if (!isPaymentEvent && !isRefundEvent)
    return { received: true, ignored: true };
  const entity = body?.payload?.[isRefundEvent ? "refund" : "payment"]?.entity;
  if (!entity)
    throw Object.assign(new Error("Webhook event payload is incomplete"), {
      status: 422,
    });
  const client = await pool().connect();
  try {
    await client.query("BEGIN");
    const inserted = await client.query(
      `INSERT IGNORE INTO payment_webhook_events(provider,event_id,payload) VALUES('razorpay',$1,$2)`,
      [eventId, JSON.stringify(body)],
    );
    if (!inserted.insertId) {
      await client.query("ROLLBACK");
      return { received: true, duplicate: true };
    }
    let result;
    let state;
    if (isPaymentEvent) {
      const payment = (
        await client.query(
          `SELECT id,amount,currency FROM payments WHERE provider='razorpay' AND provider_order_id=$1`,
          [entity.order_id],
        )
      ).rows[0];
      if (
        !payment ||
        Number(entity.amount) !== Math.round(Number(payment.amount) * 100) ||
        entity.currency !== payment.currency
      )
        throw Object.assign(
          new Error("Webhook payment does not match a transaction"),
          { status: 409 },
        );
      state =
        event === "payment.captured"
          ? "captured"
          : event === "payment.authorized"
            ? "authorized"
            : "failed";
      await applyVerifiedState(client, payment.id, state, entity.id, {
        code: entity.error_code,
        description: entity.error_description,
      });
      result = { paymentId: payment.id, status: state };
      await client.query(
        `INSERT INTO audit_logs(action,entity_type,entity_id,metadata) VALUES($1,'payment',$2,$3)`,
        [
          `payment.webhook_${state}`,
          payment.id,
          JSON.stringify({ eventId, providerPaymentId: entity.id }),
        ],
      );
    } else {
      const refund = (
        await client.query(
          `SELECT r.id,r.payment_id,r.amount,p.provider_payment_id FROM payment_refunds r JOIN payments p ON p.id=r.payment_id WHERE r.provider_refund_id=$1 OR r.reference=$2 ORDER BY (r.provider_refund_id=$1) DESC LIMIT 1 FOR UPDATE`,
          [entity.id, entity.notes?.signfix_refund_reference || ""],
        )
      ).rows[0];
      if (
        !refund ||
        refund.provider_payment_id !== entity.payment_id ||
        Number(entity.amount) !== Math.round(Number(refund.amount) * 100)
      )
        throw Object.assign(
          new Error("Webhook refund does not match a transaction"),
          { status: 409 },
        );
      state =
        event === "refund.processed"
          ? "processed"
          : event === "refund.failed"
            ? "failed"
            : "pending";
      await applyRefundState(client, refund.id, state, entity.id, entity);
      result = { refundId: refund.id, paymentId: refund.payment_id, status: state };
      await client.query(
        `INSERT INTO audit_logs(action,entity_type,entity_id,metadata) VALUES($1,'payment',$2,$3)`,
        [
          `payment.refund_webhook_${state}`,
          refund.payment_id,
          JSON.stringify({ eventId, providerRefundId: entity.id }),
        ],
      );
    }
    await client.query("COMMIT");
    if (
      isPaymentEvent &&
      state === "authorized" &&
      razorpay.autoCaptureEnabled()
    )
      await razorpay
        .capturePayment(entity.id, entity.amount, entity.currency)
        .catch((error) =>
          console.error("[payment] Razorpay capture failed:", error.message),
        );
    return { received: true, ...result };
  } catch (e) {
    await client.query("ROLLBACK");
    throw e;
  } finally {
    client.release();
  }
}
module.exports = {
  create,
  createForOrder,
  retry,
  cancel,
  confirm,
  reportFailure,
  get,
  list,
  createRefund,
  listRefunds,
  webhook,
};
