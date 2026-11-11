// Uses the modular firebase-admin API (works on firebase-admin 10 through 14+).
// The old namespaced API (admin.credential.cert / admin.auth() / admin.messaging())
// is gone in firebase-admin 14, which made Firebase Admin impossible to start.
const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getMessaging } = require('firebase-admin/messaging');

let app;
let configurationErrorLogged = false;

function credentials() {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  let privateKey = process.env.FIREBASE_PRIVATE_KEY;
  if (!projectId || !clientEmail || !privateKey) return null;

  // Normalize quotes and trim first
  privateKey = String(privateKey).trim().replace(/^["']|["']$/g, '').trim();

  // Support base64-encoded private keys (ideal for cPanel / bash environments with no spaces)
  if (!privateKey.includes('-----BEGIN')) {
    try {
      const cleanB64 = privateKey.replace(/[\s"']/g, '');
      const decoded = Buffer.from(cleanB64, 'base64').toString('utf8');
      if (decoded.includes('-----BEGIN PRIVATE KEY-----')) {
        privateKey = decoded;
      }
    } catch (_) {}
  }

  // Normalize escaped newlines
  privateKey = privateKey.replace(/\\n/g, '\n');

  if (privateKey && !privateKey.includes('-----BEGIN PRIVATE KEY-----')) {
    if (!configurationErrorLogged) {
      configurationErrorLogged = true;
      console.error("[Firebase Admin Error] FIREBASE_PRIVATE_KEY is invalid: You have entered the 'private_key_id' (e.g. fe4c78...) instead of the full RSA 'private_key'. The private key must start with '-----BEGIN PRIVATE KEY-----' and end with '-----END PRIVATE KEY-----'. Firebase Admin is disabled until a valid private key is configured.");
    }
    return null;
  }

  return { projectId, clientEmail, privateKey };
}

function getApp() {
  if (app) return app;
  const serviceAccount = credentials();
  if (!serviceAccount) return null;
  try {
    app = getApps().length ? getApps()[0] : initializeApp({ credential: cert(serviceAccount) });
  } catch (error) {
    // Push is optional. A bad/misquoted secret must not make unrelated
    // customer API routes (including /notifications/config) return 500.
    if (!configurationErrorLogged) {
      configurationErrorLogged = true;
      console.error('Firebase Admin configuration is invalid; push notifications are disabled:', error.message);
    }
    return null;
  }
  return app;
}

async function sendToTokens(tokens, notification, data = {}) {
  const firebaseApp = getApp();
  if (!firebaseApp || !tokens.length) return { configured: Boolean(firebaseApp), successCount: 0, failureCount: 0 };
  const response = await getMessaging(firebaseApp).sendEachForMulticast({
    tokens,
    notification,
    data: Object.fromEntries(Object.entries(data).map(([key, value]) => [key, String(value)])),
    webpush: { fcmOptions: { link: process.env.APP_URL || '/' } },
  });
  return { configured: true, successCount: response.successCount, failureCount: response.failureCount };
}

async function verifyIdToken(idToken) {
  const firebaseApp = getApp();
  if (!firebaseApp) {
    let hint = 'Check FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, and FIREBASE_PRIVATE_KEY in environment.';
    const pk = process.env.FIREBASE_PRIVATE_KEY || '';
    if (pk && !pk.includes('-----BEGIN PRIVATE KEY-----')) {
      hint = "FIREBASE_PRIVATE_KEY is invalid: you entered 'private_key_id' (fe4c78...) instead of the full RSA 'private_key' starting with '-----BEGIN PRIVATE KEY-----'.";
    }
    throw Object.assign(
      new Error(`Firebase Admin is not configured. ${hint}`),
      { status: 503, code: 'FIREBASE_NOT_CONFIGURED' }
    );
  }
  return await getAuth(firebaseApp).verifyIdToken(idToken);
}

module.exports = { sendToTokens, verifyIdToken, isConfigured: () => Boolean(getApp()), getApp };
