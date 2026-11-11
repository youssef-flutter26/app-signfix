const { whatsapp } = require('../config');

function normalize(number = '') {
  const digits = String(number).replace(/\D/g, '');
  if (!digits) return '';
  return digits.length === 10 ? `91${digits}` : digits;
}

// Lazy require avoids a circular dependency: database.js calls into this
// module, and this module only needs database.js's pool at call time.
function pool() { return require('../database').getPool(); }

async function queueOrderEvent(orderId, eventKey, customerUserId, mobile, message) {
  const recipient = normalize(mobile);
  const inserted = await pool().query(
    `INSERT IGNORE INTO order_whatsapp_logs(order_id,customer_user_id,event_key,recipient,message,status) VALUES($1,$2,$3,$4,$5,'pending')`,
    [orderId, customerUserId, eventKey, recipient, message]
  );
  if (!inserted.insertId) return;
  const logId = inserted.insertId;
  if (!recipient || !whatsapp.accessToken || !whatsapp.phoneNumberId) {
    await pool().query(`UPDATE order_whatsapp_logs SET status='skipped',error_message=$2,attempted_at=NOW() WHERE id=$1`, [logId, !recipient ? 'Customer mobile number is unavailable' : 'WhatsApp provider is not configured']);
    return;
  }
  try {
    const response = await fetch(`https://graph.facebook.com/${whatsapp.apiVersion}/${whatsapp.phoneNumberId}/messages`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${whatsapp.accessToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ messaging_product: 'whatsapp', recipient_type: 'individual', to: recipient, type: 'text', text: { preview_url: false, body: message } }),
    });
    const body = await response.json();
    if (!response.ok) throw new Error(body?.error?.message || `WhatsApp API returned ${response.status}`);
    await pool().query(`UPDATE order_whatsapp_logs SET status='sent',provider_message_id=$2,attempted_at=NOW() WHERE id=$1`, [logId, body.messages?.[0]?.id]);
  } catch (error) {
    await pool().query(`UPDATE order_whatsapp_logs SET status='failed',error_message=$2,attempted_at=NOW() WHERE id=$1`, [logId, String(error.message).slice(0, 1000)]);
  }
}

module.exports = { queueOrderEvent, normalize };
