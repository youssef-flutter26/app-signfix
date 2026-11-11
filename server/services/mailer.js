const nodemailer = require('nodemailer');

function smtpConfig() {
  return {
    host: process.env.SMTP_HOST || '',
    port: Number(process.env.SMTP_PORT || 465),
    secure: process.env.SMTP_SECURE !== 'false',
    user: process.env.SMTP_USER || '',
    pass: process.env.SMTP_PASS || '',
    from: process.env.SMTP_FROM || process.env.SMTP_USER || '',
    timeoutMs: Number(process.env.SMTP_TIMEOUT_MS || 10000),
  };
}

function isConfigured() {
  const cfg = smtpConfig();
  return Boolean(cfg.host && cfg.user && cfg.pass && cfg.from);
}

// Created on first use so a missing/invalid SMTP setup only fails when a
// message is actually sent, not at server startup. Shared by every
// transactional email (OTP, order AWB) so one SMTP pool serves them all.
let transporter = null;
function getTransporter() {
  if (transporter) return transporter;
  if (!isConfigured()) {
    throw Object.assign(new Error('Email is not configured. Set SMTP_HOST, SMTP_USER, SMTP_PASS and SMTP_FROM.'), { status: 503, errorCode: 'EMAIL_NOT_CONFIGURED' });
  }
  const cfg = smtpConfig();
  transporter = nodemailer.createTransport({
    host: cfg.host,
    port: cfg.port,
    secure: cfg.secure,
    auth: { user: cfg.user, pass: cfg.pass },
    connectionTimeout: cfg.timeoutMs,
    greetingTimeout: cfg.timeoutMs,
    socketTimeout: cfg.timeoutMs,
  });
  return transporter;
}

function normalizeEmail(email = '') {
  const value = String(email).trim().toLowerCase();
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value) ? value : '';
}

// Sends one message and returns the provider message id. Provider failures are
// wrapped so callers can record a short reason without leaking SMTP internals.
async function sendMail({ to, subject, text, html }) {
  let info;
  try {
    info = await getTransporter().sendMail({ from: smtpConfig().from, to, subject, text, html });
  } catch (error) {
    if (error && error.errorCode === 'EMAIL_NOT_CONFIGURED') throw error;
    throw Object.assign(new Error(`Email provider could not send the message: ${error.message}`), { status: 502, errorCode: 'EMAIL_PROVIDER_UNAVAILABLE' });
  }
  return { messageId: info && info.messageId ? info.messageId : null };
}

module.exports = {
  smtpConfig,
  isConfigured,
  getTransporter,
  normalizeEmail,
  sendMail,
  // Test-only: drops the cached transporter between cases.
  _resetTransporter() { transporter = null; },
};
