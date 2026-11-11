// Lazy requires avoid a circular dependency: delhiveryService triggers these
// emails and this module only needs the mailer, the pool and the link builder
// at call time.
function defaultDeps() {
  const mailer = require('./mailer');
  return {
    isConfigured: mailer.isConfigured,
    normalizeEmail: mailer.normalizeEmail,
    sendMail: mailer.sendMail,
    pool: require('../database').getPool,
    publicTrackingUrl: require('./delhiveryService').publicTrackingUrl,
  };
}

// Test-only seam so unit tests can drive the pool and the mailer without a
// MySQL or SMTP server. Production code never sets this.
let overrides = {};
const deps = () => ({ ...defaultDeps(), ...overrides });

// Created on first use so existing MySQL deployments need no manual migration.
let schemaPromise = null;
function ensureSchema() {
  if (schemaPromise) return schemaPromise;
  schemaPromise = deps().pool().query(`CREATE TABLE IF NOT EXISTS order_email_logs (id BIGINT AUTO_INCREMENT PRIMARY KEY, order_id BIGINT NOT NULL, customer_user_id BIGINT, event_key VARCHAR(120) NOT NULL, recipient VARCHAR(190), subject VARCHAR(255), body TEXT, status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','sent','failed','skipped')), provider_message_id VARCHAR(255), error_message TEXT, attempted_at DATETIME, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, INDEX idx_order_email_logs_order(order_id), INDEX idx_order_email_logs_created(created_at DESC), FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE, FOREIGN KEY(customer_user_id) REFERENCES users(id))`)
    .catch((error) => { schemaPromise = null; throw error; });
  return schemaPromise;
}

const escapeHtml = (value) => String(value == null ? '' : value).replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));

function awbMail({ name, orderNo, waybill, productName, trackingUrl }) {
  const greeting = name ? `Hi ${name},` : 'Hi,';
  const subject = `Your SignFix order ${orderNo} is on the way - AWB ${waybill}`;
  const intro = 'Good news! Your order has been handed over to our delivery partner and is on its way to you. Keep the tracking number below to follow its progress.';
  const details = [
    ['Order number', orderNo],
    ...(productName ? [['Item', productName]] : []),
    ['Tracking number (AWB)', waybill],
  ];
  const text = [
    'SignFix', '', greeting, '', intro, '',
    ...details.map(([label, value]) => `${label}: ${value}`),
    '', `Track your shipment: ${trackingUrl}`, '',
    'We will email you again as the shipment moves. Reply to this email if you need help.', '',
    'Thanks,', 'The SignFix Team',
  ].join('\n');
  const rows = details.map(([label, value]) => `<tr><td style="padding:6px 16px 6px 0;color:#667085;font-size:14px">${escapeHtml(label)}</td><td style="padding:6px 0;color:#172033;font-size:14px;font-weight:600">${escapeHtml(value)}</td></tr>`).join('');
  const html = `<div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto;padding:24px;color:#172033">`
    + `<h2 style="margin:0 0 12px">SignFix</h2>`
    + `<p style="margin:0 0 16px">${escapeHtml(greeting)}</p>`
    + `<p style="margin:0 0 16px">${escapeHtml(intro)}</p>`
    + `<table style="border-collapse:collapse;margin:0 0 20px">${rows}</table>`
    + `<p style="margin:0 0 20px"><a href="${escapeHtml(trackingUrl)}" style="display:inline-block;background:#102a63;color:#fff;text-decoration:none;padding:12px 20px;border-radius:6px">Track your shipment</a></p>`
    + `<p style="margin:0 0 8px;color:#667085;font-size:13px">If the button does not work, open this link:<br>${escapeHtml(trackingUrl)}</p>`
    + `<p style="margin:0;color:#667085;font-size:13px">We will email you again as the shipment moves. Reply to this email if you need help.</p></div>`;
  return { subject, text, html };
}

// Emails the AWB to the customer who placed the order. Never throws: a missing
// address or an SMTP outage must not roll back the order or the waybill.
// Retries are safe - a waybill that already went out successfully is skipped,
// while a previously failed attempt is sent again.
async function queueAwbEmail(orderDatabaseId, waybill) {
  const awb = String(waybill || '').trim();
  if (!awb) return { status: 'skipped', reason: 'No waybill to send' };
  const { isConfigured, normalizeEmail, sendMail, publicTrackingUrl } = deps();
  try {
    await ensureSchema();
    const db = deps().pool();
    const order = (await db.query(
      'SELECT o.id,o.order_no,c.user_id,u.name,u.email,COALESCE(JSON_UNQUOTE(JSON_EXTRACT(o.specifications,\'$.product\')),\'Sign board\') AS product FROM orders o JOIN customers c ON c.id=o.customer_id JOIN users u ON u.id=c.user_id WHERE o.id=$1',
      [orderDatabaseId],
    )).rows[0];
    if (!order) return { status: 'skipped', reason: 'Order not found' };

    const eventKey = `awb_assigned_${awb}`;
    const alreadySent = await db.query('SELECT 1 FROM order_email_logs WHERE order_id=$1 AND event_key=$2 AND status=\'sent\' LIMIT 1', [order.id, eventKey]);
    if (alreadySent.rowCount) return { status: 'skipped', reason: 'AWB email already sent' };

    const recipient = normalizeEmail(order.email);
    const mail = awbMail({ name: order.name, orderNo: order.order_no, waybill: awb, productName: order.product, trackingUrl: publicTrackingUrl(awb) });
    const log = await db.query(
      `INSERT INTO order_email_logs(order_id,customer_user_id,event_key,recipient,subject,body,status) VALUES($1,$2,$3,$4,$5,$6,'pending')`,
      [order.id, order.user_id, eventKey, recipient, mail.subject, mail.text],
    );
    const logId = log.insertId;
    const record = (status, error = null, providerMessageId = null) => db.query(
      'UPDATE order_email_logs SET status=$1,error_message=$2,provider_message_id=$3,attempted_at=NOW() WHERE id=$4',
      [status, error, providerMessageId, logId],
    );
    if (!recipient) {
      await record('skipped', 'Customer email address is missing or invalid');
      return { status: 'skipped', reason: 'Customer email address is missing or invalid' };
    }
    if (!isConfigured()) {
      await record('skipped', 'Email provider is not configured');
      return { status: 'skipped', reason: 'Email provider is not configured' };
    }
    try {
      const { messageId } = await sendMail({ to: recipient, ...mail });
      await record('sent', null, messageId);
      return { status: 'sent', recipient, messageId };
    } catch (error) {
      await record('failed', String(error.message || 'Email could not be sent').slice(0, 1000));
      return { status: 'failed', recipient, reason: error.message };
    }
  } catch (error) {
    console.error(`[EMAIL] AWB email for order ${orderDatabaseId} could not be queued:`, error.message);
    return { status: 'failed', reason: error.message };
  }
}

module.exports = {
  queueAwbEmail,
  awbMail,
  ensureSchema,
  // Test-only: swaps the pool/mailer/tracking-link dependencies and clears the
  // cached schema promise.
  _setDeps(next = {}) { overrides = next; schemaPromise = null; },
};
