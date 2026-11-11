const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const { isCorsOriginAllowed, uploadDir } = require('./config');
const asyncHandler = require('./utils/asyncHandler');

// Express 4 does not catch a rejected promise thrown by an async route
// handler; left unwrapped, that becomes an unhandled rejection and crashes
// the whole process instead of returning a JSON error. Every router created
// from here on has its route methods auto-wrapped so async errors are
// forwarded to errorHandler below instead of taking the server down.
const originalCreateRouter = express.Router;
express.Router = function patchedRouter(...routerArgs) {
  const router = originalCreateRouter(...routerArgs);
  for (const method of ['get', 'post', 'put', 'patch', 'delete', 'all', 'use']) {
    const original = router[method].bind(router);
    router[method] = (...handlers) => original(...handlers.map((handler) => (typeof handler === 'function' ? asyncHandler(handler) : handler)));
  }
  return router;
};

const routes = require('./routes');
const { notFound, errorHandler } = require('./middleware/errorHandler');
const rateLimit = require('./middleware/rateLimit');

fs.mkdirSync(uploadDir, { recursive: true });
const app = express();
app.set('trust proxy', 1);

app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' },
  contentSecurityPolicy: {
    directives: {
      imgSrc: ["'self'", 'data:', 'blob:', 'https:'],
      connectSrc: ["'self'", 'https:', 'wss:'],
      workerSrc: ["'self'", 'blob:'],
      // Razorpay Checkout loads checkout.js and renders its payment form in
      // an iframe served from Razorpay domains.
      scriptSrc: ["'self'", 'https://checkout.razorpay.com'],
      frameSrc: ["'self'", 'https://api.razorpay.com', 'https://checkout.razorpay.com'],
    },
  },
}));

app.use(cors({
  origin(origin, callback) {
    if (isCorsOriginAllowed(origin)) return callback(null, true);
    callback(Object.assign(new Error('Origin is not allowed by CORS'), { status: 403 }));
  },
}));

app.use(express.json({
  limit: '2mb',
  verify: (req, _res, buffer) => {
    if (req.originalUrl.startsWith('/api/payments/webhook')) req.rawBody = buffer;
  },
}));

app.use('/api', rateLimit({ windowMs: 15 * 60 * 1000, max: 1000 }));
app.use('/api', routes);
// Never let an unknown API request fall through to the SPA HTML response.
app.use('/api', notFound);

// ── Legal pages (required for Google OAuth production approval) ──────────────
app.get('/privacy', (_req, res) => {
  res.set('Content-Type', 'text/html; charset=utf-8');
  res.set('Cache-Control', 'public, max-age=86400');
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Privacy Policy – SignFix</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 760px; margin: 40px auto; padding: 0 20px; color: #1e293b; line-height: 1.7; }
    h1 { color: #0f172a; } h2 { color: #1e293b; margin-top: 2em; }
    a { color: #d97706; }
  </style>
</head>
<body>
  <h1>Privacy Policy</h1>
  <p><strong>Last updated:</strong> November 2026</p>
  <p>SignFix ("we", "us", or "our") operates the SignFix mobile application and website at <a href="https://signfix.me">signfix.me</a>. This page explains how we collect, use, and protect your information.</p>

  <h2>Information We Collect</h2>
  <ul>
    <li><strong>Account information:</strong> Name, email address, and phone number when you register or sign in with Google.</li>
    <li><strong>Order information:</strong> Sign board specifications, delivery address, and service requests you submit.</li>
    <li><strong>Location data:</strong> Approximate location used only to validate our service area. Never stored permanently.</li>
    <li><strong>Device information:</strong> Firebase Cloud Messaging token for push notifications.</li>
  </ul>

  <h2>How We Use Your Information</h2>
  <ul>
    <li>To process and track your sign board orders and service requests.</li>
    <li>To send order status updates and service notifications.</li>
    <li>To verify your identity via Google Sign-In or phone OTP.</li>
    <li>To communicate with you about your account.</li>
  </ul>

  <h2>Data Sharing</h2>
  <p>We do not sell your personal information. We share data only with service providers necessary to operate our platform (payment processing, SMS delivery, cloud storage).</p>

  <h2>Data Retention</h2>
  <p>We retain your account and order data for as long as your account is active or as required by law. You may request deletion by contacting us.</p>

  <h2>Google Sign-In</h2>
  <p>When you sign in with Google, we receive your name and email address from Google. We do not receive or store your Google password. Your use of Google Sign-In is also governed by <a href="https://policies.google.com/privacy" target="_blank" rel="noopener">Google's Privacy Policy</a>.</p>

  <h2>Security</h2>
  <p>We use industry-standard encryption (HTTPS/TLS) for all data in transit. Passwords are hashed and never stored in plain text.</p>

  <h2>Contact Us</h2>
  <p>For privacy questions or data deletion requests, contact us at: <a href="mailto:hello@signfix.me">hello@signfix.me</a></p>
</body>
</html>`);
});

app.get('/terms', (_req, res) => {
  res.set('Content-Type', 'text/html; charset=utf-8');
  res.set('Cache-Control', 'public, max-age=86400');
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Terms of Service – SignFix</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 760px; margin: 40px auto; padding: 0 20px; color: #1e293b; line-height: 1.7; }
    h1 { color: #0f172a; } h2 { color: #1e293b; margin-top: 2em; }
    a { color: #d97706; }
  </style>
</head>
<body>
  <h1>Terms of Service</h1>
  <p><strong>Last updated:</strong> November 2026</p>
  <p>By using SignFix, you agree to these terms. SignFix provides sign board ordering, fabrication, and maintenance services through its app and website.</p>

  <h2>Use of Service</h2>
  <p>You must provide accurate information when placing orders. SignFix reserves the right to cancel orders with incorrect or incomplete details.</p>

  <h2>Payments</h2>
  <p>Payments are processed securely via Razorpay. All prices are in Indian Rupees (INR) and inclusive of applicable taxes unless stated otherwise.</p>

  <h2>Cancellations & Refunds</h2>
  <p>Orders may be cancelled before fabrication begins. Contact <a href="mailto:hello@signfix.me">hello@signfix.me</a> for refund requests.</p>

  <h2>Contact</h2>
  <p><a href="mailto:hello@signfix.me">hello@signfix.me</a> | <a href="https://signfix.me">signfix.me</a></p>
</body>
</html>`);
});

const adminBuild = path.resolve(__dirname, '../dist');
const adminIndex = path.join(adminBuild, 'index.html');
const configuredMarketingBuild = process.env.MARKETING_WEB_ROOT?.trim();
const marketingBuild = path.resolve(configuredMarketingBuild || path.resolve(__dirname, '../../signfix_web/out'));
const marketingIndex = path.join(marketingBuild, 'index.html');

// Never run a Vite production build during an HTTP server startup. On cPanel/
// Passenger this can make the whole website appear to hang for 30-60+ seconds.
// Build during deployment instead (`npm run build`).

const hasAdminBuild = fs.existsSync(adminIndex);
const hasMarketingBuild = fs.existsSync(marketingIndex);

if (!hasAdminBuild && process.env.NODE_ENV === 'production') {
  throw new Error(`Admin production build is missing at ${adminIndex}; run npm run build before starting the server`);
}

if (configuredMarketingBuild && !hasMarketingBuild && process.env.NODE_ENV === 'production') {
  throw new Error(`Marketing production build is missing at ${marketingIndex}; build signfix_web before starting the server`);
}

if (hasAdminBuild) {
  // Vite currently emits root-based asset URLs. Next.js uses /_next, so the
  // two generated asset namespaces do not collide.
  app.use('/assets', express.static(path.join(adminBuild, 'assets'), { maxAge: '1y', immutable: true }));

  const firebaseWorker = path.join(adminBuild, 'firebase-messaging-sw.js');
  if (fs.existsSync(firebaseWorker)) {
    app.get('/firebase-messaging-sw.js', (_req, res, next) => {
      res.set('Cache-Control', 'no-cache');
      res.sendFile(firebaseWorker, (error) => error && next(error));
    });
  }
}

if (hasMarketingBuild) {
  // The admin SPA owns only /admin and its nested browser routes.
  app.get(/^\/admin(?:\/.*)?$/, (_req, res, next) => {
    if (!hasAdminBuild) return next();
    res.set('Cache-Control', 'no-cache');
    return res.sendFile(adminIndex, (error) => error && next(error));
  });

  // Serve hashed Next.js files aggressively, while keeping generated HTML
  // fresh. `extensions` supports clean exported URLs such as /about.
  app.use('/_next/static', express.static(path.join(marketingBuild, '_next/static'), { maxAge: '1y', immutable: true }));

  // A Next.js export can contain both `about.html` and an `about/` directory
  // containing RSC data. Resolve the HTML file before express.static sees the
  // directory, otherwise it redirects to /about/ and misses the page.
  app.get(/.*/, (req, res, next) => {
    let route;
    try {
      route = decodeURIComponent(req.path).replace(/\\/g, '/').replace(/^\/+|\/+$/g, '');
    } catch (_) {
      return next();
    }
    if (!route || route.includes('\0') || path.posix.extname(route)) return next();

    const htmlFile = path.resolve(marketingBuild, `${route}.html`);
    const relativeFile = path.relative(marketingBuild, htmlFile);
    const isInsideBuild = relativeFile && relativeFile !== '..' && !relativeFile.startsWith(`..${path.sep}`) && !path.isAbsolute(relativeFile);
    if (!isInsideBuild || !fs.existsSync(htmlFile) || !fs.statSync(htmlFile).isFile()) return next();

    res.set('Cache-Control', 'no-cache');
    return res.sendFile(htmlFile, (error) => error && next(error));
  });

  app.use(express.static(marketingBuild, {
    extensions: ['html'],
    maxAge: '1h',
    setHeaders(res, filePath) {
      if (path.extname(filePath).toLowerCase() === '.html') res.set('Cache-Control', 'no-cache');
    },
  }));

  const marketingNotFound = path.join(marketingBuild, '404.html');
  app.get(/.*/, (_req, res, next) => {
    if (!fs.existsSync(marketingNotFound)) return next();
    res.status(404).set('Cache-Control', 'no-cache');
    return res.sendFile(marketingNotFound, (error) => error && next(error));
  });
} else if (hasAdminBuild) {
  // Backward-compatible fallback for deployments that contain only this
  // repository: serve the admin SPA at both / and /admin.
  app.get(/.*/, (_req, res, next) => {
    res.set('Cache-Control', 'no-cache');
    res.sendFile(adminIndex, (error) => error && next(error));
  });
} else {
  app.get('/', (_req, res) => res.json({ name: 'SignFix API', status: 'ok', health: '/api/health' }));
}

app.use(notFound);
app.use(errorHandler);

module.exports = app;
