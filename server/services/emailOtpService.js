const { normalizeEmail, sendMail, _resetTransporter } = require('./mailer');

function maskEmail(email = '') {
  const value = String(email).trim();
  const at = value.indexOf('@');
  if (at <= 0) return '';
  const name = value.slice(0, at);
  return `${name.slice(0, 2)}${'*'.repeat(Math.max(1, name.length - 2))}${value.slice(at)}`;
}

function otpMail(email, otp, purpose) {
  const isReset = purpose === 'reset_password';
  const subject = isReset ? 'Your SignFix password reset code' : 'Your SignFix verification code';
  const intro = isReset
    ? 'Use the code below to reset your SignFix password. It expires in 10 minutes.'
    : 'Use the code below to verify your SignFix account. It expires in 10 minutes.';
  const text = `SignFix\n\n${intro}\n\nYour code: ${otp}\n\nIf you did not request this, you can ignore this email.`;
  const html = `<div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto;padding:24px;color:#172033">`
    + `<h2 style="margin:0 0 12px">SignFix</h2>`
    + `<p style="margin:0 0 16px">${intro}</p>`
    + `<p style="font-size:32px;font-weight:700;letter-spacing:8px;margin:0 0 16px">${otp}</p>`
    + `<p style="margin:0;color:#667085;font-size:13px">If you did not request this, you can ignore this email.</p></div>`;
  return { to: email, subject, text, html };
}

async function sendEmailOtp(email, otp, purpose = 'verify_registration') {
  const recipient = normalizeEmail(email);
  if (!recipient) throw Object.assign(new Error('A valid email address is required'), { status: 422 });
  if (!/^\d{6}$/.test(String(otp))) throw Object.assign(new Error('A 6-digit OTP is required'), { status: 422, errorCode: 'EMAIL_OTP_INVALID' });

  const { messageId } = await sendMail(otpMail(recipient, String(otp), purpose));
  return { recipient, messageId };
}

module.exports = {
  normalizeEmail,
  maskEmail,
  sendEmailOtp,
  // Test-only: drops the cached transporter between cases.
  _resetTransporter,
};
