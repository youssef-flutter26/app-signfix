const { whatsapp } = require('../config');

function normalizeWhatsAppNumber(number = '') {
  const raw = String(number).trim();
  const digits = raw.replace(/\D/g, '');
  if (!digits) return '';
  // SignFix is primarily India-focused: accept 10-digit Indian numbers and
  // convert them to the international WhatsApp format.
  if (digits.length === 10) return `91${digits}`;
  if (digits.length >= 11 && digits.length <= 15) return digits;
  return '';
}

async function sendWhatsAppOtp(number, otp) {
  const recipient = normalizeWhatsAppNumber(number);
  if (!recipient) throw Object.assign(new Error('A valid WhatsApp mobile number is required'), { status: 422 });

  if (!whatsapp.accessToken || !whatsapp.phoneNumberId || !whatsapp.otpTemplateName) {
    throw Object.assign(new Error('WhatsApp OTP is not configured. Set WHATSAPP_ACCESS_TOKEN, WHATSAPP_PHONE_NUMBER_ID and WHATSAPP_OTP_TEMPLATE_NAME.'), { status: 503 });
  }

  const url = `https://graph.facebook.com/${whatsapp.apiVersion}/${whatsapp.phoneNumberId}/messages`;
  const payload = {
    messaging_product: 'whatsapp',
    recipient_type: 'individual',
    to: recipient,
    type: 'template',
    template: {
      name: whatsapp.otpTemplateName,
      language: { code: whatsapp.otpTemplateLanguage },
      components: [
        {
          type: 'body',
          parameters: [{ type: 'text', text: String(otp) }],
        },
        // Meta authentication templates with a COPY_CODE OTP button are sent
        // using the URL subtype at send time. Templates without a button must
        // not receive this component, or Meta rejects the parameter count.
        ...(whatsapp.otpTemplateHasButton ? [{
          type: 'button',
          sub_type: 'url',
          index: '0',
          parameters: [{ type: 'text', text: String(otp) }],
        }] : []),
      ],
    },
  };

  const timeoutMs = Number(process.env.WHATSAPP_TIMEOUT_MS || 7000);
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  let response;
  try {
    response = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${whatsapp.accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
    signal: controller.signal,
  });
  } catch (error) {
    if (error?.name === 'AbortError') {
      throw Object.assign(new Error('WhatsApp service timed out. Please try resending the OTP.'), { status: 504, errorCode: 'WHATSAPP_TIMEOUT' });
    }
    throw Object.assign(new Error(`WhatsApp service is temporarily unavailable: ${error.message}`), { status: 502, errorCode: 'WHATSAPP_PROVIDER_UNAVAILABLE' });
  } finally {
    clearTimeout(timer);
  }

  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    const detail = body?.error?.message || `WhatsApp API returned ${response.status}`;
    throw Object.assign(new Error(`WhatsApp OTP could not be sent: ${detail}`), { status: 502, providerError: body?.error });
  }

  return {
    recipient,
    messageId: body?.messages?.[0]?.id || null,
  };
}

function maskWhatsAppNumber(number = '') {
  const normalized = normalizeWhatsAppNumber(number);
  if (!normalized) return '';
  return `+${normalized.slice(0, 2)} ${'X'.repeat(Math.max(0, normalized.length - 6))}${normalized.slice(-4)}`;
}

module.exports = { normalizeWhatsAppNumber, maskWhatsAppNumber, sendWhatsAppOtp };
