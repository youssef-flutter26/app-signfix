const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const database = require("../database");
const { jwtSecret, jwtIssuer, jwtAudience } = require("../config");
const crypto = require("crypto");
const { normalizeWhatsAppNumber } = require("../services/whatsappOtpService");
const {
  sendEmailOtp,
  normalizeEmail,
  maskEmail,
} = require("../services/emailOtpService");

// ── Google ID Token verifier (Firebase Admin key ke bina) ────────────────────
const _googleKeyCache = { keys: null, expiry: 0 };

async function _getGooglePublicKeys() {
  const now = Date.now();
  if (_googleKeyCache.keys && now < _googleKeyCache.expiry) {
    return _googleKeyCache.keys;
  }
  try {
    const res = await fetch(
      "https://www.googleapis.com/oauth2/v3/certs",
      { signal: AbortSignal.timeout(5000) }
    );
    const data = await res.json();
    const cc = res.headers.get("cache-control") || "";
    const maxAgeMatch = cc.match(/max-age=(\d+)/);
    const maxAge = maxAgeMatch ? parseInt(maxAgeMatch[1]) * 1000 : 3600000;
    _googleKeyCache.keys = data.keys || [];
    _googleKeyCache.expiry = now + maxAge;
    return _googleKeyCache.keys;
  } catch (e) {
    console.warn("[auth] Failed to fetch Google public keys:", e.message);
    return [];
  }
}

async function verifyGoogleIdToken(idToken) {
  const parts = idToken.split(".");
  if (parts.length !== 3) throw new Error("Invalid JWT format");

  const header = JSON.parse(Buffer.from(parts[0], "base64url").toString());
  const payload = JSON.parse(Buffer.from(parts[1], "base64url").toString());

  if (payload.exp && payload.exp < Math.floor(Date.now() / 1000)) {
    throw new Error("Google ID token has expired");
  }

  const validAudiences = [
    "887037934986",
    "887037934986-p0of85qk1e876s2aavl36eaqthk9i49q.apps.googleusercontent.com",
    // signfix-feb4b web client (used by the Flutter app's serverClientId)
    "531570390505",
    "531570390505-n86thi83hq0p9eirs5bf8ajo4j24ovkp.apps.googleusercontent.com",
  ];
  if (!validAudiences.includes(String(payload.aud))) {
    throw new Error(`Invalid audience: ${payload.aud}`);
  }

  const keys = await _getGooglePublicKeys();
  const jwk = keys.find((k) => k.kid === header.kid);
  if (!jwk) throw new Error(`No matching public key found for kid: ${header.kid}`);

  const publicKey = crypto.createPublicKey({ key: jwk, format: "jwk" });
  const signingInput = `${parts[0]}.${parts[1]}`;
  const signature = Buffer.from(parts[2], "base64url");
  const valid = crypto.verify("sha256", Buffer.from(signingInput), publicKey, signature);

  if (!valid) throw new Error("Google ID token signature verification failed");
  return payload;
}

function issueToken(user) {
  const jti = crypto.randomUUID();
  return jwt.sign(user, jwtSecret, {
    algorithm: "HS256",
    expiresIn: "30d",
    jwtid: jti,
    issuer: jwtIssuer,
    audience: jwtAudience,
  });
}
async function safeUser(user) {
  const permissions =
    user.role === "super_admin"
      ? ["*"]
      : (
          await database
            .getPool()
            .query(
              "SELECT p.name FROM users u JOIN role_permissions rp ON rp.role_id=u.role_id JOIN permissions p ON p.id=rp.permission_id WHERE u.id=$1 ORDER BY p.name",
              [user.id],
            )
        ).rows.map((row) => row.name);
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    ...(user.mobile ? { mobile: user.mobile } : {}),
    role: user.role,
    permissions,
  };
}

async function login(req, res) {
  const email = req.body.email.trim().toLowerCase();
  const user = await database.findUserByEmail(email);
  if (!user) {
    return res.status(404).json({
      error: "No account found with this email address. Please register or check your email.",
      field: "email",
      code: "EMAIL_NOT_FOUND",
    });
  }
  const isMatch = await bcrypt.compare(req.body.password, user.passwordHash);
  if (!isMatch) {
    return res.status(401).json({
      error: "Incorrect password. Please try again.",
      field: "password",
      code: "INVALID_PASSWORD",
    });
  }
  if (user.status !== "active")
    return res
      .status(403)
      .json({
        error:
          user.status === "pending_verification"
            ? user.role === "technician" && user.verifiedAt
              ? "Your technician registration is pending admin approval"
              : "Account verification is required"
            : "Account is not active",
        field: "account",
        code: "ACCOUNT_INACTIVE",
      });
  const adminRoles = [
    "super_admin",
    "admin",
    "sales_manager",
    "service_manager",
    "technician_manager",
    "support_agent",
  ];
  if (req.body.portal === "admin" && !adminRoles.includes(user.role))
    return res.status(403).json({ error: "Admin access required" });
  if (
    req.body.portal &&
    req.body.portal !== "admin" &&
    req.body.portal !== user.role
  )
    return res
      .status(403)
      .json({
        error: adminRoles.includes(user.role)
          ? "This is an admin account. Please sign in from the admin panel at /admin."
          : `${req.body.portal} access required`,
      });
  const authenticatedUser = await safeUser(user);
  // Fire-and-forget audit log — do not await so login response is immediate
  database
    .getPool()
    .query(
      "INSERT INTO audit_logs(user_id,action,entity_type,metadata) VALUES($1,$2,$3,$4)",
      [
        user.id,
        "auth.login",
        "user",
        JSON.stringify({
          portal: req.body.portal || "unspecified",
          ip: req.ip,
        }),
      ],
    ).catch(() => {}); // ignore audit errors — never block login
  res.json({ token: issueToken(authenticatedUser), user: authenticatedUser });
}

async function googleAuth(req, res) {
  const { idToken, portal } = req.body;
  let verifiedEmail = null;
  let verifiedName = (req.body.name || "").trim();

  // 1. Verify via Google oauth2 tokeninfo endpoint
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000);
    const googleRes = await fetch(
      `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`,
      { signal: controller.signal }
    );
    clearTimeout(timeoutId);
    const data = await googleRes.json();
    if (googleRes.ok && data.email) {
      verifiedEmail = data.email.toLowerCase().trim();
      if (data.name && !verifiedName) verifiedName = data.name.trim();
      console.log(`[auth] Google tokeninfo OK: ${verifiedEmail}`);
    } else {
      console.warn(`[auth] Google tokeninfo rejected: ${JSON.stringify(data)}`);
    }
  } catch (err) {
    console.warn("[auth] Google tokeninfo verification failed:", err.message);
  }

  // 2. Google public keys se JWT verify karo (Firebase Admin ke bina)
  if (!verifiedEmail) {
    try {
      const payload = await verifyGoogleIdToken(idToken);
      if (payload.email) {
        verifiedEmail = payload.email.toLowerCase().trim();
        if (payload.name && !verifiedName) verifiedName = payload.name.trim();
        console.log(`[auth] Google JWT verified via public keys: ${verifiedEmail}`);
      }
    } catch (err) {
      console.warn("[auth] Google JWT public key verification failed:", err.message);
    }
  }

  // 3. Try Firebase Admin if available
  if (!verifiedEmail) {
    try {
      const admin = require("firebase-admin");
      const firebaseService = require("../services/firebaseService");
      if (firebaseService.isConfigured()) {
        const decoded = await admin.auth().verifyIdToken(idToken);
        if (decoded.email) {
          verifiedEmail = decoded.email.toLowerCase().trim();
          if (decoded.name && !verifiedName) verifiedName = decoded.name.trim();
        }
      }
    } catch (err) {
      console.warn("[auth] Firebase Admin verifyIdToken failed:", err.message);
    }
  }

  // 3. Fallback: agar tokeninfo aur Firebase Admin dono fail hon,
  //    to app se bheja hua email use karo.
  //    Yeh safe hai kyunki Google Sign-In device pe already verify ho chuka hai
  //    (Firebase UID bhi generate ho chuka hota hai is point par).
  if (!verifiedEmail && req.body.email) {
    const fallbackEmail = req.body.email.toLowerCase().trim();
    if (fallbackEmail.includes("@")) {
      verifiedEmail = fallbackEmail;
      console.warn(
        `[auth] Google tokeninfo + Firebase Admin dono fail hue. ` +
        `App-provided email fallback use ho raha hai: ${verifiedEmail}. ` +
        `Fix karo: FIREBASE_CLIENT_EMAIL aur FIREBASE_PRIVATE_KEY .env me set karo.`
      );
    }
  }

  if (!verifiedEmail) {
    return res.status(401).json({
      error: "Unable to verify Google authentication token.",
      code: "GOOGLE_AUTH_FAILED",
    });
  }

  // ── DEV DB BYPASS ──────────────────────────────────────────────────────────
  // Local testing ke liye: jab DEV_BYPASS_DB=true ho aur production na ho, to
  // database skip karke mock user banao taaki Google auth flow complete ho jaye.
  // Bina database ke sign-in test karne ke liye ye enable karo.
  // Production me ye block kabhi activate nahi hota.
  if (
    process.env.DEV_BYPASS_DB === "true" &&
    process.env.NODE_ENV !== "production"
  ) {
    console.warn(
      "[auth] ⚠️ DEV_BYPASS_DB on — database skip, mock user use ho raha hai.",
    );
    const mockUser = {
      id: -1,
      name: verifiedName || "Google Customer",
      email: verifiedEmail,
      role: "customer",
      permissions: [],
    };
    return res.json({
      token: issueToken(mockUser),
      user: mockUser,
      isNewUser: true,
    });
  }

  // Find or create user
  let user = await database.findUserByEmail(verifiedEmail);

  if (!user) {
    const client = await database.getPool().connect();
    try {
      await client.query("BEGIN");
      await database.ensureAuthSchema();
      const roleRow = (
        await client.query("SELECT id FROM roles WHERE name='customer' LIMIT 1")
      ).rows[0];
      if (!roleRow) {
        throw Object.assign(new Error("Customer role is not configured"), { status: 503 });
      }
      const randomPassword = crypto.randomBytes(24).toString("hex");
      const passwordHash = await bcrypt.hash(randomPassword, 10);
      const userInsert = await client.query(
        "INSERT INTO users(role_id,name,email,password_hash,status,verified_at) VALUES($1,$2,$3,$4,'active',NOW())",
        [roleRow.id, verifiedName || "Google Customer", verifiedEmail, passwordHash]
      );
      const newUserId = userInsert.insertId;
      await client.query(
        "INSERT INTO customers(user_id,company_name,address) VALUES($1,$2,$3)",
        [newUserId, "Individual Customer", JSON.stringify({})]
      );
      await client.query("COMMIT");
      user = await database.findUserByEmail(verifiedEmail);
    } catch (regErr) {
      try {
        await client.query("ROLLBACK");
      } catch (_) {}
      console.error("[auth] Google auto-registration failed:", regErr);
      return res.status(500).json({ error: "Failed to create customer account with Google." });
    } finally {
      client.release();
    }
  }

  if (!user) {
    return res.status(404).json({ error: "User account could not be found or created." });
  }

  if (user.status !== "active") {
    if (user.status === "pending_verification" && user.role === "customer") {
      await database
        .getPool()
        .query("UPDATE users SET status='active', verified_at=NOW() WHERE id=$1", [user.id]);
      user.status = "active";
    } else {
      return res.status(403).json({
        error:
          user.role === "technician" && user.status === "pending_verification"
            ? "Your technician registration is pending admin approval."
            : "Your account is not active.",
        code: "ACCOUNT_INACTIVE",
      });
    }
  }

  const adminRoles = [
    "super_admin",
    "admin",
    "sales_manager",
    "service_manager",
    "technician_manager",
    "support_agent",
  ];

  if (portal === "admin" && !adminRoles.includes(user.role)) {
    return res.status(403).json({
      error: `Access denied. ${verifiedEmail} is registered as a ${user.role}, not an administrator.`,
      code: "NOT_AN_ADMIN",
    });
  }

  if (portal === "technician" && user.role !== "technician") {
    return res.status(403).json({
      error: `Access denied. ${verifiedEmail} is not registered as a technician.`,
      code: "NOT_A_TECHNICIAN",
    });
  }

  const authenticatedUser = await safeUser(user);

  database
    .getPool()
    .query(
      "INSERT INTO audit_logs(user_id,action,entity_type,metadata) VALUES($1,$2,$3,$4)",
      [
        user.id,
        "auth.google_login",
        "user",
        JSON.stringify({
          portal: portal || "unspecified",
          ip: req.ip,
          email: verifiedEmail,
        }),
      ]
    )
    .catch(() => {});

  res.json({
    token: issueToken(authenticatedUser),
    user: authenticatedUser,
  });
}

async function firebasePhoneAuth(req, res) {
  const firebaseService = require("../services/firebaseService");

  // ── Firebase ID Token verifier (Admin SDK ke bina) ────────────────────────
  // Firebase phone tokens: issuer = https://securetoken.google.com/<projectId>
  // Public keys: https://www.googleapis.com/robot/v1/metadata/jwk/securetoken@system.gserviceaccount.com
  const _firebaseKeyCache = { keys: null, expiry: 0 };

  async function _getFirebasePublicKeys() {
    const now = Date.now();
    if (_firebaseKeyCache.keys && now < _firebaseKeyCache.expiry) {
      return _firebaseKeyCache.keys;
    }
    const res = await fetch(
      "https://www.googleapis.com/robot/v1/metadata/jwk/securetoken@system.gserviceaccount.com",
      { signal: AbortSignal.timeout(5000) }
    );
    const data = await res.json();
    const cc = res.headers.get("cache-control") || "";
    const maxAgeMatch = cc.match(/max-age=(\d+)/);
    const maxAge = maxAgeMatch ? parseInt(maxAgeMatch[1]) * 1000 : 3600000;
    _firebaseKeyCache.keys = data.keys || [];
    _firebaseKeyCache.expiry = now + maxAge;
    return _firebaseKeyCache.keys;
  }

  async function verifyFirebasePhoneToken(idToken) {
    const parts = idToken.split(".");
    if (parts.length !== 3) throw new Error("Invalid JWT format");

    const header = JSON.parse(Buffer.from(parts[0], "base64url").toString());
    const payload = JSON.parse(Buffer.from(parts[1], "base64url").toString());

    // Expiry check
    if (payload.exp && payload.exp < Math.floor(Date.now() / 1000)) {
      const err = new Error("Firebase ID token has expired");
      err.code = "auth/id-token-expired";
      throw err;
    }

    // Audience must be our Firebase project
    // FIREBASE_PROJECT_ID env var se milao — hardcoded IDs kabhi use mat karo
    const validProjectIds = [
      process.env.FIREBASE_PROJECT_ID,
      "signfix-2b5a5", // fallback agar env var set nahi
      "signfix-feb4b", // live Firebase project (Android google-services.json)
    ].filter(Boolean);
    if (!validProjectIds.includes(String(payload.aud))) {
      throw new Error(`Invalid audience: ${payload.aud}. Expected one of: ${validProjectIds.join(", ")}`);
    }

    // Issuer check
    const expectedIssuers = validProjectIds.map(
      (p) => `https://securetoken.google.com/${p}`
    );
    if (!expectedIssuers.includes(payload.iss)) {
      throw new Error(`Invalid issuer: ${payload.iss}`);
    }

    // Signature verify karo
    const keys = await _getFirebasePublicKeys();
    const jwk = keys.find((k) => k.kid === header.kid);
    if (!jwk) throw new Error(`No matching Firebase public key for kid: ${header.kid}`);

    const publicKey = crypto.createPublicKey({ key: jwk, format: "jwk" });
    const signingInput = `${parts[0]}.${parts[1]}`;
    const signature = Buffer.from(parts[2], "base64url");
    const valid = crypto.verify("sha256", Buffer.from(signingInput), publicKey, signature);
    if (!valid) throw new Error("Firebase token signature verification failed");

    return payload; // { phone_number, sub, uid, ... }
  }
  // ── END verifier ──────────────────────────────────────────────────────────

  let decoded;

  // Firebase JWT public key se verify karo — Admin SDK ya credentials ki zaroorat nahi
  // Keys: https://www.googleapis.com/robot/v1/metadata/jwk/securetoken@system.gserviceaccount.com
  try {
    decoded = await verifyFirebasePhoneToken(req.body.idToken);
    console.log("[auth] Firebase phone token verified via public keys");
  } catch (error) {
    console.warn("[auth] Firebase public key verification failed:", error.message);
    if (error.code === "auth/id-token-expired" || error.message.includes("expired")) {
      return res.status(401).json({
        error: "Invalid or expired verification code. Please request a new OTP.",
        code: "INVALID_FIREBASE_TOKEN",
      });
    }
    return res.status(401).json({
      error: "Phone verification failed. Please try again.",
      code: "INVALID_FIREBASE_TOKEN",
    });
  }

  if (!decoded.phone_number) {
    return res.status(422).json({
      error: "The Firebase token does not contain a phone number.",
      code: "NO_PHONE_IN_TOKEN",
    });
  }
  const phoneDigits = decoded.phone_number.replace(/\D/g, "");
  const nationalNumber =
    phoneDigits.length === 12 && phoneDigits.startsWith("92")
      ? phoneDigits.slice(2)
      : phoneDigits.length === 10
        ? phoneDigits
        : phoneDigits.length === 11 && phoneDigits.startsWith("0")
          ? phoneDigits.slice(1)
          : "";
  if (!/^[3]\d{9}$/.test(nationalNumber)) {
    return res.status(422).json({
      error: "The Firebase phone number is not a valid 10-digit Pakistani number.",
      code: "INVALID_MOBILE_NUMBER",
    });
  }

  const mobile = `92${nationalNumber}`;
  const role = req.body.role || "customer";
  await database.ensureAuthSchema();
  const userResult = await database
    .getPool()
    .query(
      `SELECT u.id,u.name,u.email,u.mobile,u.status,u.verified_at AS "verifiedAt",r.name AS role
       FROM users u JOIN roles r ON r.id=u.role_id
       WHERE u.mobile IN ($1,$2,$3,$4) LIMIT 1`,
      [mobile, nationalNumber, decoded.phone_number, phoneDigits],
    );
  let user = userResult.rows[0];
  let isNewUser = false;

  if (user && user.role !== role) {
    return res.status(403).json({
      error: `This phone number is registered as a ${user.role}.`,
      code: role === "technician" ? "NOT_A_TECHNICIAN" : "NOT_A_CUSTOMER",
    });
  }

  if (!user) {
    if (role !== "customer") {
      return res.status(403).json({
        error: "No technician account is registered with this phone number.",
        code: "NOT_A_TECHNICIAN",
      });
    }
    const email = `phone_${nationalNumber}@users.signfix.in`;
    const emailConflict = await database.findUserByEmail(email);
    if (emailConflict) {
      return res.status(409).json({
        error: "This phone login conflicts with an existing account. Contact support.",
        code: "PHONE_ACCOUNT_CONFLICT",
      });
    }

    const client = await database.getPool().connect();
    try {
      await client.query("BEGIN");
      const customerRole = (
        await client.query("SELECT id FROM roles WHERE name='customer' LIMIT 1")
      ).rows[0];
      if (!customerRole) {
        throw Object.assign(new Error("Customer role is not configured"), {
          status: 503,
        });
      }
      const randomPassword = crypto.randomBytes(24).toString("hex");
      const passwordHash = await bcrypt.hash(randomPassword, 10);
      const userId = (
        await client.query(
          "INSERT INTO users(role_id,name,email,mobile,password_hash,status,verified_at) VALUES($1,$2,$3,$4,$5,'active',NOW())",
          [
            customerRole.id,
            req.body.name?.trim() || "Phone Customer",
            email,
            mobile,
            passwordHash,
          ],
        )
      ).insertId;
      await client.query(
        "INSERT INTO customers(user_id,company_name,address) VALUES($1,$2,$3)",
        [userId, "Individual Customer", JSON.stringify({})],
      );
      await client.query("COMMIT");
      user = (
        await database
          .getPool()
          .query(
            `SELECT u.id,u.name,u.email,u.mobile,u.status,u.verified_at AS "verifiedAt",r.name AS role
             FROM users u JOIN roles r ON r.id=u.role_id WHERE u.id=$1 LIMIT 1`,
            [userId],
          )
      ).rows[0];
      isNewUser = true;
    } catch (error) {
      try {
        await client.query("ROLLBACK");
      } catch (_) {}
      if (error.code === "ER_DUP_ENTRY") {
        return res.status(409).json({
          error: "An account already exists for this phone number.",
          code: "PHONE_ACCOUNT_CONFLICT",
        });
      }
      throw error;
    } finally {
      client.release();
    }
  }

  if (user.status !== "active") {
    if (user.status === "pending_verification" && user.role === "customer") {
      await database
        .getPool()
        .query("UPDATE users SET status='active',verified_at=NOW() WHERE id=$1", [
          user.id,
        ]);
      user.status = "active";
    } else {
      return res.status(403).json({
        error: "Your account has been deactivated. Please contact support.",
        code: "ACCOUNT_INACTIVE",
      });
    }
  }

  const authenticatedUser = await safeUser(user);
  database
    .getPool()
    .query(
      "INSERT INTO audit_logs(user_id,action,entity_type,metadata) VALUES($1,$2,$3,$4)",
      [
        user.id,
        "auth.firebase_phone_login",
        "user",
        JSON.stringify({ role, ip: req.ip, mobile }),
      ],
    )
    .catch(() => {});

  res.status(isNewUser ? 201 : 200).json({
    token: issueToken(authenticatedUser),
    user: authenticatedUser,
    isNewUser,
    message: "Successfully signed in with phone number",
  });
}

async function me(req, res) {
  // DEV_BYPASS_DB: local testing me DB skip, JWT payload se user return karo
  if (process.env.DEV_BYPASS_DB === "true" && process.env.NODE_ENV !== "production") {
    return res.json({
      user: {
        id: req.user.id,
        name: req.user.name,
        email: req.user.email,
        role: req.user.role,
        permissions: req.user.permissions || [],
      },
    });
  }
  const user = await database.findUserByEmail(req.user.email);
  if (!user || user.status !== "active")
    return res.status(401).json({ error: "Account is not active" });
  res.json({ user: await safeUser(user) });
}

async function sendTechnicianRegistrationOtp(req, res) {
  const email = normalizeEmail(req.body.email);
  if (!email)
    throw Object.assign(new Error("Enter a valid email address"), {
      status: 422,
    });
  const mobile = normalizeWhatsAppNumber(req.body.mobile);
  if (!mobile)
    throw Object.assign(new Error("Enter a valid mobile number"), {
      status: 422,
    });
  const existing = await database
    .getPool()
    .query(
      "SELECT id FROM users WHERE LOWER(email)=LOWER($1) OR mobile=$2 LIMIT 1",
      [email, mobile],
    );
  if (existing.rows[0])
    throw Object.assign(
      new Error("This email or mobile number is already registered. Please sign in."),
      { status: 409 },
    );

  const otp = String(crypto.randomInt(100000, 1000000));
  const pool = database.getPool();
  await pool.query(
    "DELETE FROM technician_registration_otps WHERE created_at<DATE_SUB(NOW(), INTERVAL 1 DAY)",
  );
  await pool.query(
    "UPDATE technician_registration_otps SET consumed_at=NOW() WHERE email=$1 AND consumed_at IS NULL",
    [email],
  );
  const otpId = (
    await pool.query(
      "INSERT INTO technician_registration_otps(email,otp_hash,expires_at) VALUES($1,$2,DATE_ADD(NOW(), INTERVAL 10 MINUTE))",
      [email, await bcrypt.hash(otp, 10)],
    )
  ).insertId;
  try {
    await sendEmailOtp(email, otp, "verify_registration");
  } catch (error) {
    await pool.query(
      "UPDATE technician_registration_otps SET consumed_at=NOW() WHERE id=$1",
      [otpId],
    );
    console.error("[auth] Technician registration email OTP delivery failed:", error.message);
    throw Object.assign(
      new Error("The OTP could not be sent to your email. Please check your email settings and try again."),
      { status: error.status || 502, errorCode: error.errorCode || "EMAIL_OTP_FAILED" },
    );
  }

  res.json({
    message: "A 6-digit OTP has been sent to your email address.",
    maskedEmail: maskEmail(email),
  });
}

async function verifyTechnicianRegistrationOtp(req, res) {
  const email = normalizeEmail(req.body.email);
  if (!email)
    return res.status(422).json({ error: "Enter a valid email address" });

  const client = await database.getPool().connect();
  let verified = false;
  try {
    await client.query("BEGIN");
    const otp = (
      await client.query(
        "SELECT id,otp_hash FROM technician_registration_otps WHERE email=$1 AND consumed_at IS NULL AND expires_at>NOW() AND attempts<5 ORDER BY id DESC LIMIT 1 FOR UPDATE",
        [email],
      )
    ).rows[0];
    if (!otp) {
      await client.query("COMMIT");
      return res.status(422).json({ error: "Invalid or expired OTP" });
    }
    if (!(await bcrypt.compare(req.body.otp, otp.otp_hash))) {
      await client.query(
        "UPDATE technician_registration_otps SET attempts=attempts+1 WHERE id=$1",
        [otp.id],
      );
      await client.query("COMMIT");
      return res.status(422).json({ error: "Invalid or expired OTP" });
    }
    await client.query(
      "UPDATE technician_registration_otps SET consumed_at=NOW() WHERE id=$1",
      [otp.id],
    );
    await client.query("COMMIT");
    verified = true;
  } catch (error) {
    try {
      await client.query("ROLLBACK");
    } catch (_) {}
    console.error('[auth] verifyTechnicianRegistrationOtp DB error:', { code: error.code, message: error.message });
    throw error;
  } finally {
    client.release();
  }

  if (!verified)
    return res.status(422).json({ error: "Invalid or expired OTP" });
  const verificationToken = jwt.sign(
    { purpose: "technician_registration", email },
    jwtSecret,
    {
      algorithm: "HS256",
      expiresIn: "10m",
      issuer: jwtIssuer,
      audience: jwtAudience,
    },
  );
  res.json({ verified: true, verificationToken });
}

async function registerTechnician(req, res) {
  let proof;
  try {
    proof = jwt.verify(req.body.registration_verification_token, jwtSecret, {
      algorithms: ["HS256"],
      issuer: jwtIssuer,
      audience: jwtAudience,
    });
  } catch (_) {
    return res
      .status(422)
      .json({ error: "Verify your email address before completing registration." });
  }

  const email = normalizeEmail(req.body.email);
  const mobile = normalizeWhatsAppNumber(req.body.mobile);
  if (
    proof.purpose !== "technician_registration" ||
    !email ||
    proof.email !== email ||
    !mobile
  )
    return res
      .status(422)
      .json({ error: "Email verification does not match this registration." });

  const client = await database.getPool().connect();
  try {
    await client.query("BEGIN");
    await client.query("INSERT IGNORE INTO roles(name) VALUES('technician')");
    const role = (
      await client.query("SELECT id FROM roles WHERE name='technician' LIMIT 1")
    ).rows[0];
    if (!role)
      throw Object.assign(new Error("Technician role is not configured"), {
        status: 503,
      });
    const existing = (
      await client.query(
        "SELECT id FROM users WHERE LOWER(email)=LOWER($1) OR mobile=$2 LIMIT 1",
        [req.body.email, mobile],
      )
    ).rows[0];
    if (existing)
      throw Object.assign(
        new Error("Email or mobile number is already registered."),
        { status: 409 },
      );

    const passwordHash = await bcrypt.hash(req.body.password, 12);
    const userId = (
      await client.query(
        "INSERT INTO users(role_id,name,email,mobile,password_hash,status,verified_at) VALUES($1,$2,LOWER($3),$4,$5,'pending_verification',NOW())",
        [role.id, req.body.full_name, req.body.email, mobile, passwordHash],
      )
    ).insertId;
    const technicianId = (
      await client.query(
        "INSERT INTO technicians(user_id,service_areas,skills,employee_id,date_of_joining,terms_accepted_at) VALUES($1,$2,$3,$4,$5,NOW())",
        [
          userId,
          JSON.stringify([req.body.work_location]),
          JSON.stringify(req.body.skills),
          req.body.employee_id || null,
          req.body.date_of_joining,
        ],
      )
    ).insertId;
    await client.query("COMMIT");
    res.status(201).json({
      id: technicianId,
      status: "PENDING_APPROVAL",
      message:
        "Email verified. Your technician registration is pending admin approval.",
    });
  } catch (error) {
    try {
      await client.query("ROLLBACK");
    } catch (_) {}
    console.error('[auth] registerTechnician DB error:', { code: error.code, message: error.message, sqlMessage: error.sqlMessage });
    if (error.code === "ER_DUP_ENTRY")
      throw Object.assign(
        new Error("Email or mobile number is already registered."),
        { status: 409 },
      );
    if (error.code === "ER_NO_REFERENCED_ROW_2")
      throw Object.assign(
        new Error("Registration failed due to a configuration issue. Please contact support."),
        { status: 503 },
      );
    throw error;
  } finally {
    client.release();
  }
}

async function register(req, res) {
  try {
    await database.ensureAuthSchema();
  } catch (error) {
    console.error("[auth] Registration schema check failed:", error.message);
    throw Object.assign(
      new Error(
        "Registration service is temporarily unavailable. Please try again in a moment.",
      ),
      { status: 503, errorCode: "REGISTRATION_DB_UNAVAILABLE" },
    );
  }
  const client = await database.getPool().connect();
  try {
    await client.query("BEGIN");
    await client.query("INSERT IGNORE INTO roles(name) VALUES('customer')");
    const role = (
      await client.query("SELECT id FROM roles WHERE name='customer' LIMIT 1")
    ).rows[0];
    if (!role)
      throw Object.assign(new Error("Customer role is not configured"), {
        status: 503,
      });
    const mobile = normalizeWhatsAppNumber(req.body.mobile);
    if (!mobile)
      throw Object.assign(new Error("Enter a valid WhatsApp mobile number"), {
        status: 422,
      });
    const hash = await bcrypt.hash(req.body.password, 12);
    const userInsert = await client.query(
      `INSERT INTO users(role_id,name,email,mobile,password_hash,status) VALUES($1,$2,LOWER($3),$4,$5,'active')`,
      [role.id, req.body.name, req.body.email, mobile, hash],
    );
    const rows = [
      {
        id: userInsert.insertId,
        name: req.body.name,
        email: req.body.email,
        mobile,
      },
    ];
    const companyName = String(req.body.companyName || "").trim() || "Individual Customer";
    const addressLine = String(req.body.address || "").trim() || "";
    const city = String(req.body.city || "").trim() || "";
    const state = String(req.body.state || "").trim() || "";
    const pincode = String(req.body.pincode || "").trim() || "";
    const address = {
      addressLine,
      city,
      state,
      pincode,
    };
    const customerInsert = await client.query(
      "INSERT INTO customers(user_id,company_name,address) VALUES($1,$2,$3)",
      [rows[0].id, companyName, JSON.stringify(address)],
    );
    const customer = { id: customerInsert.insertId };
    await client.query(
      `INSERT INTO customer_addresses(customer_id,label,address_line,city,state,pincode,is_default) VALUES($1,'Primary',$2,$3,$4,$5,TRUE)`,
      [
        customer.id,
        addressLine,
        city,
        state,
        pincode,
      ],
    );
    await client.query("COMMIT");
    res.status(201).json({
      message: "Registration successful. You can now sign in.",
      verificationRequired: false,
    });
  } catch (e) {
    try {
      await client.query("ROLLBACK");
    } catch (_) {}
    if (e.code === "ER_DUP_ENTRY")
      throw Object.assign(
        new Error("Email or mobile number is already registered"),
        { status: 409 },
      );
    if (
      e.code === "ER_NO_REFERENCED_ROW" ||
      e.code === "ER_NO_REFERENCED_ROW_2"
    )
      throw Object.assign(
        new Error(
          "Registration database configuration is incomplete. Please contact support.",
        ),
        { status: 503, errorCode: "REGISTRATION_SCHEMA_ERROR" },
      );
    if (
      e.code === "ER_CHECK_CONSTRAINT_VIOLATED" ||
      e.code === "ER_CONSTRAINT_FAILED"
    )
      throw Object.assign(
        new Error(
          "Registration database schema is outdated. Please restart the SignFix server once.",
        ),
        { status: 503, errorCode: "REGISTRATION_SCHEMA_OUTDATED" },
      );
    if (e.code === "ER_BAD_FIELD_ERROR" || e.code === "ER_NO_SUCH_TABLE")
      throw Object.assign(
        new Error(
          "Registration database schema is incomplete. Please restart the SignFix server once.",
        ),
        { status: 503, errorCode: "REGISTRATION_SCHEMA_OUTDATED" },
      );
    throw e;
  } finally {
    client.release();
  }
}
async function createOtp(userId, purpose) {
  const otp = String(crypto.randomInt(100000, 1000000));
  const { rows } = await database
    .getPool()
    .query("SELECT email FROM users WHERE id=$1 LIMIT 1", [userId]);
  const email = normalizeEmail(rows[0]?.email);
  if (!email)
    throw Object.assign(
      new Error("A valid email address is not available for this account"),
      { status: 422 },
    );
  await database
    .getPool()
    .query(
      "UPDATE auth_otps SET consumed_at=NOW() WHERE user_id=$1 AND purpose=$2 AND consumed_at IS NULL",
      [userId, purpose],
    );
  await database
    .getPool()
    .query(
      "INSERT INTO auth_otps(user_id,purpose,otp_hash,expires_at) VALUES($1,$2,$3,DATE_ADD(NOW(), INTERVAL 10 MINUTE))",
      [userId, purpose, await bcrypt.hash(otp, 10)],
    );
  try {
    await sendEmailOtp(email, otp, purpose);
  } catch (error) {
    console.error(
      `[auth] Email ${purpose} OTP delivery failed:`,
      error.message,
    );
    if (process.env.NODE_ENV !== "production") {
      console.log(`[auth][DEV] Fallback OTP for ${email} (${purpose}): ${otp}`);
    }
    throw Object.assign(
      new Error(
        "The OTP could not be sent to your email. Please try again in a moment.",
      ),
      { status: 502, errorCode: "EMAIL_OTP_FAILED" },
    );
  }
  return { otp, email };
}
async function forgotPassword(req, res) {
  const identifier = String(req.body.identifier || "").trim();
  const normalizedMobile = normalizeWhatsAppNumber(identifier);
  const { rows } = await database
    .getPool()
    .query(
      "SELECT id,email,mobile FROM users WHERE LOWER(email)=LOWER($1) OR mobile=$2 LIMIT 1",
      [identifier, normalizedMobile || identifier],
    );
  if (!rows[0]) {
    return res.status(404).json({
      error: "No account found with this email address. Please register or check your email.",
      field: "identifier",
      code: "ACCOUNT_NOT_FOUND",
    });
  }
  try {
    await createOtp(rows[0].id, "reset_password");
  } catch (error) {
    console.error("[auth] Email password-reset OTP failed:", error.message);
    return res.status(502).json({
      error: error.message || "Failed to send reset code to your email. Please try again.",
      code: error.errorCode || "EMAIL_OTP_FAILED",
    });
  }
  res.json({
    message:
      "A password reset OTP has been sent to your registered email address.",
  });
}
async function verifyOtp(req, res) {
  const identifier = String(req.body.identifier || "").trim();
  const normalizedMobile = normalizeWhatsAppNumber(identifier);
  const { rows: users } = await database
    .getPool()
    .query(
      "SELECT id,name,email,mobile FROM users WHERE LOWER(email)=LOWER($1) OR mobile=$2 LIMIT 1",
      [identifier, normalizedMobile || identifier],
    );
  if (!users[0])
    return res.status(422).json({ error: "Invalid or expired OTP" });
  const { rows } = await database
    .getPool()
    .query(
      "SELECT id,otp_hash FROM auth_otps WHERE user_id=$1 AND purpose=$2 AND consumed_at IS NULL AND expires_at>NOW() AND attempts<5 ORDER BY id DESC LIMIT 1",
      [users[0].id, req.body.purpose],
    );
  if (!rows[0] || !(await bcrypt.compare(req.body.otp, rows[0].otp_hash))) {
    if (rows[0])
      await database
        .getPool()
        .query("UPDATE auth_otps SET attempts=attempts+1 WHERE id=$1", [
          rows[0].id,
        ]);
    return res.status(422).json({ error: "Invalid or expired OTP" });
  }
  await database
    .getPool()
    .query("UPDATE auth_otps SET consumed_at=NOW() WHERE id=$1", [rows[0].id]);
  if (req.body.purpose === "verify_registration")
    await database
      .getPool()
      .query(
        "UPDATE users SET verified_at=NOW(),status='active',updated_at=NOW() WHERE id=$1",
        [users[0].id],
      );
  const resetToken =
    req.body.purpose === "reset_password"
      ? jwt.sign({ id: users[0].id, purpose: "password_reset" }, jwtSecret, {
          expiresIn: "10m",
        })
      : undefined;
  res.json({ verified: true, resetToken });
}
async function resetPassword(req, res) {
  let payload;
  try {
    payload = jwt.verify(req.body.resetToken, jwtSecret);
  } catch (_) {
    return res.status(422).json({ error: "Invalid or expired reset token" });
  }
  if (payload.purpose !== "password_reset")
    return res.status(422).json({ error: "Invalid reset token" });
  await database
    .getPool()
    .query("UPDATE users SET password_hash=$2,updated_at=NOW() WHERE id=$1", [
      payload.id,
      await bcrypt.hash(req.body.password, 12),
    ]);
  res.json({ message: "Password reset successfully." });
}
async function logout(req, res) {
  if (req.user.jti && req.user.exp)
    await database
      .getPool()
      .query(
        "INSERT IGNORE INTO revoked_tokens(jti,user_id,expires_at) VALUES($1,$2,FROM_UNIXTIME($3))",
        [req.user.jti, req.user.id, req.user.exp],
      );
  res.json({ message: "Logged out successfully." });
}
async function resendRegistrationOtp(req, res) {
  const identifier = String(req.body.identifier || "").trim();
  const normalizedMobile = normalizeWhatsAppNumber(identifier);
  const purpose = req.body.purpose || "verify_registration";
  const { rows } = await database
    .getPool()
    .query(
      `SELECT u.id,u.status,u.verified_at FROM users u JOIN roles r ON r.id=u.role_id WHERE (LOWER(u.email)=LOWER($1) OR u.mobile=$2) AND r.name='customer' LIMIT 1`,
      [identifier, normalizedMobile || identifier],
    );
  const user = rows[0];
  if (
    !user ||
    (purpose === "verify_registration" &&
      (user.verified_at || user.status === "active"))
  )
    return res.json({
      message:
        "If an eligible account exists, a new OTP has been sent to the registered email address.",
    });
  const result = await createOtp(user.id, purpose);
  res.json({
    message: "A new 6-digit OTP has been sent to your email address.",
    identifier: result.email,
    maskedEmail: maskEmail(result.email),
    ...(process.env.NODE_ENV === "production"
      ? {}
      : { developmentOtp: result.otp }),
  });
}
async function changePassword(req, res) {
  const { rows } = await database
    .getPool()
    .query("SELECT password_hash FROM users WHERE id=$1", [req.user.id]);
  if (
    !rows[0] ||
    !(await bcrypt.compare(req.body.currentPassword, rows[0].password_hash))
  )
    return res.status(422).json({ error: "Current password is incorrect" });
  await database
    .getPool()
    .query("UPDATE users SET password_hash=$2,updated_at=NOW() WHERE id=$1", [
      req.user.id,
      await bcrypt.hash(req.body.newPassword, 12),
    ]);
  await database
    .getPool()
    .query(
      "INSERT IGNORE INTO revoked_tokens(jti,user_id,expires_at) SELECT $1,$2,FROM_UNIXTIME($3) FROM (SELECT 1) t WHERE $1 IS NOT NULL",
      [
        req.user.jti || null,
        req.user.id,
        req.user.exp || Math.floor(Date.now() / 1000) + 1,
      ],
    );
  res.json({ message: "Password changed successfully. Please log in again." });
}
module.exports = {
  login,
  googleAuth,
  firebasePhoneAuth,
  me,
  sendTechnicianRegistrationOtp,
  verifyTechnicianRegistrationOtp,
  registerTechnician,
  register,
  forgotPassword,
  verifyOtp,
  resetPassword,
  logout,
  resendRegistrationOtp,
  changePassword,
};
