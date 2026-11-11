const database = require("../database");

// Delhivery B2C tracking API. A single call accepts up to 50 comma-separated
// waybills; responses are cached in order_shipments so customer page loads do
// not hit Delhivery on every request.
const BATCH_SIZE = 50;

function config() {
  return {
    token: process.env.DELHIVERY_API_TOKEN || "",
    baseUrl: (
      process.env.DELHIVERY_BASE_URL || "https://track.delhivery.com"
    ).replace(/\/$/, ""),
    timeoutMs: Number(process.env.DELHIVERY_TIMEOUT_MS || 10000),
    cacheMinutes: Number(process.env.DELHIVERY_TRACKING_CACHE_MINUTES || 15),
  };
}
function isEnabled() {
  return Boolean(config().token);
}

// Created on first use so existing MySQL deployments need no manual migration.
let schemaPromise = null;
function ensureSchema() {
  if (schemaPromise) return schemaPromise;
  schemaPromise = database
    .getPool()
    .query(
      `CREATE TABLE IF NOT EXISTS order_shipments (id BIGINT AUTO_INCREMENT PRIMARY KEY, order_id BIGINT NOT NULL, provider VARCHAR(30) NOT NULL DEFAULT 'delhivery', waybill VARCHAR(40) NOT NULL UNIQUE, status VARCHAR(80), status_type VARCHAR(10), status_location VARCHAR(160), status_at VARCHAR(40), expected_delivery VARCHAR(40), origin VARCHAR(120), destination VARCHAR(120), delivered BOOLEAN NOT NULL DEFAULT FALSE, scans JSON, last_error TEXT, last_synced_at DATETIME, created_by BIGINT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, INDEX idx_order_shipments_order(order_id), FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE, FOREIGN KEY(created_by) REFERENCES users(id))`,
    )
    .catch((error) => {
      schemaPromise = null;
      throw error;
    });
  return schemaPromise;
}

// Collapses Delhivery's status/status-type pair into one stable stage for UIs.
function stageOf(status = "", statusType = "") {
  const s = String(status).toLowerCase(),
    t = String(statusType).toUpperCase();
  if (/rto|return/.test(s) || t === "RT") return "returned";
  if (t === "CN" || /cancel/.test(s)) return "cancelled";
  if (t === "DL" || s === "delivered") return "delivered";
  // Delhivery reuses UD as the catch-all type for every undelivered forward
  // scan (Manifested, Not Picked, In Transit, Pending and Dispatched all report
  // UD), so only the status wording can separate out-for-delivery here.
  if (/dispatched|out for delivery/.test(s)) return "out_for_delivery";
  if (/manifested|not picked|pickup/.test(s) || t === "PP") return "manifested";
  return status ? "in_transit" : "pending";
}

function normalizeShipment(shipment = {}) {
  const current = shipment.Status || {};
  const scans = (shipment.Scans || [])
    .map(({ ScanDetail: d = {} }) => ({
      status: d.Scan || null,
      statusType: d.ScanType || null,
      location: d.ScannedLocation || null,
      instructions: d.Instructions || null,
      at: d.ScanDateTime || d.StatusDateTime || null,
    }))
    .sort((a, b) => String(b.at || "").localeCompare(String(a.at || "")));
  return {
    waybill: String(shipment.AWB || ""),
    status: current.Status || null,
    statusType: current.StatusType || null,
    statusLocation: current.StatusLocation || null,
    statusAt: current.StatusDateTime || null,
    instructions: current.Instructions || null,
    expectedDelivery:
      shipment.ExpectedDeliveryDate || shipment.PromisedDeliveryDate || null,
    origin: shipment.Origin || null,
    destination: shipment.Destination || null,
    stage: stageOf(current.Status, current.StatusType),
    scans,
  };
}

// Returns a Map of waybill -> normalized shipment. Waybills Delhivery does not
// know are simply absent from the map.
async function fetchTracking(waybills) {
  const { token, baseUrl, timeoutMs } = config();
  if (!token)
    throw Object.assign(new Error("Delhivery tracking is not configured"), {
      status: 503,
      errorCode: "DELHIVERY_NOT_CONFIGURED",
    });
  const result = new Map();
  for (let i = 0; i < waybills.length; i += BATCH_SIZE) {
    const batch = waybills.slice(i, i + BATCH_SIZE);
    const url = `${baseUrl}/api/v1/packages/json/?waybill=${encodeURIComponent(batch.join(","))}`;
    let response;
    try {
      response = await fetch(url, {
        headers: {
          Authorization: `Token ${token}`,
          Accept: "application/json",
        },
        signal: AbortSignal.timeout(timeoutMs),
      });
    } catch (error) {
      throw Object.assign(
        new Error("Delhivery tracking service is unreachable"),
        { status: 502, errorCode: "DELHIVERY_UNREACHABLE", cause: error },
      );
    }
    if (response.status === 401 || response.status === 403)
      throw Object.assign(new Error("Delhivery rejected the API token"), {
        status: 502,
        errorCode: "DELHIVERY_AUTH_FAILED",
      });
    if (!response.ok)
      throw Object.assign(
        new Error(`Delhivery tracking failed with HTTP ${response.status}`),
        { status: 502, errorCode: "DELHIVERY_ERROR" },
      );
    const body = await response.json().catch(() => ({}));
    for (const item of body.ShipmentData || []) {
      const shipment = normalizeShipment(item.Shipment);
      if (shipment.waybill) result.set(shipment.waybill, shipment);
    }
  }
  return result;
}

const parseJson = (value) => {
  if (typeof value !== "string") return value || [];
  try {
    return JSON.parse(value);
  } catch (_) {
    return [];
  }
};
// Public Delhivery tracking page: the only tracking link a customer can open
// without a SignFix login, so API responses and the AWB email share it.
function publicTrackingUrl(waybill) {
  return `https://www.delhivery.com/track-v2/package/${encodeURIComponent(waybill)}`;
}
function present(row) {
  return {
    id: Number(row.id),
    provider: row.provider,
    waybill: row.waybill,
    status: row.status,
    statusType: row.status_type,
    statusLocation: row.status_location,
    statusAt: row.status_at,
    stage: stageOf(row.status, row.status_type),
    delivered: Boolean(row.delivered),
    expectedDelivery: row.expected_delivery,
    origin: row.origin,
    destination: row.destination,
    scans: parseJson(row.scans),
    lastError: row.last_error,
    lastSyncedAt: row.last_synced_at,
    createdAt: row.created_at,
    trackingUrl: publicTrackingUrl(row.waybill),
  };
}

async function saveTracking(waybill, tracking) {
  const pool = database.getPool();
  if (!tracking) {
    await pool.query(
      "UPDATE order_shipments SET last_error=$1,last_synced_at=NOW(),updated_at=NOW() WHERE waybill=$2",
      ["Waybill not found at Delhivery yet", waybill],
    );
    return;
  }
  await pool.query(
    `UPDATE order_shipments SET status=$1,status_type=$2,status_location=$3,status_at=$4,expected_delivery=$5,origin=$6,destination=$7,delivered=$8,scans=$9,last_error=NULL,last_synced_at=NOW(),updated_at=NOW() WHERE waybill=$10`,
    [
      tracking.status,
      tracking.statusType,
      tracking.statusLocation,
      tracking.statusAt,
      tracking.expectedDelivery,
      tracking.origin,
      tracking.destination,
      tracking.stage === "delivered",
      JSON.stringify(tracking.scans),
      waybill,
    ],
  );
}

// Refreshes the given rows from Delhivery. Provider failures are recorded on
// the rows instead of failing the request, so cached data is still served.
async function syncRows(rows) {
  if (!rows.length) return;
  try {
    const tracking = await fetchTracking(rows.map((row) => row.waybill));
    await Promise.all(
      rows.map((row) => saveTracking(row.waybill, tracking.get(row.waybill))),
    );
  } catch (error) {
    if (error.errorCode === "DELHIVERY_NOT_CONFIGURED") throw error;
    await database
      .getPool()
      .query(
        `UPDATE order_shipments SET last_error=$1,updated_at=NOW() WHERE waybill IN (${rows.map((_, i) => `$${i + 2}`).join(",")})`,
        [error.message, ...rows.map((row) => row.waybill)],
      );
  }
}

// Age is computed by MySQL (TIMESTAMPDIFF against NOW()) so a timezone
// difference between the DB server and Node cannot skew cache expiry.
const SELECT_SHIPMENTS =
  "SELECT *,TIMESTAMPDIFF(SECOND,last_synced_at,NOW()) AS age_seconds FROM order_shipments";
const isStale = (row) =>
  row.last_synced_at == null ||
  Number(row.age_seconds) > config().cacheMinutes * 60;

async function listOrderShipments(orderDatabaseId, { refresh = false } = {}) {
  await ensureSchema();
  const pool = database.getPool();
  const load = () =>
    pool.query(`${SELECT_SHIPMENTS} WHERE order_id=$1 ORDER BY id DESC`, [
      orderDatabaseId,
    ]);
  let { rows } = await load();
  const due = rows.filter((row) => !row.delivered && (refresh || isStale(row)));
  if (due.length && isEnabled()) {
    await syncRows(due);
    ({ rows } = await load());
  }
  return rows.map(present);
}

async function addShipment(orderDatabaseId, waybill, userId) {
  await ensureSchema();
  const pool = database.getPool();
  const existing = (
    await pool.query("SELECT order_id FROM order_shipments WHERE waybill=$1", [
      waybill,
    ])
  ).rows[0];
  if (existing && Number(existing.order_id) !== Number(orderDatabaseId))
    throw Object.assign(
      new Error("This waybill is already linked to another order"),
      { status: 409, errorCode: "WAYBILL_IN_USE" },
    );
  if (!existing)
    await pool.query(
      "INSERT INTO order_shipments(order_id,provider,waybill,created_by) VALUES($1,$2,$3,$4)",
      [orderDatabaseId, "delhivery", waybill, userId || null],
    );
  const row = (
    await pool.query("SELECT * FROM order_shipments WHERE waybill=$1", [
      waybill,
    ])
  ).rows[0];
  if (isEnabled()) await syncRows([row]);
  // Manually linked waybills reach the customer the same way auto-created ones do.
  if (!existing) notifyAwbEmail(orderDatabaseId, waybill);
  return present(
    (
      await pool.query("SELECT * FROM order_shipments WHERE waybill=$1", [
        waybill,
      ])
    ).rows[0],
  );
}

async function removeShipment(orderDatabaseId, waybill) {
  await ensureSchema();
  const { rowCount } = await database
    .getPool()
    .query("DELETE FROM order_shipments WHERE order_id=$1 AND waybill=$2", [
      orderDatabaseId,
      waybill,
    ]);
  if (!rowCount)
    throw Object.assign(new Error("Shipment not found for this order"), {
      status: 404,
    });
}

// Refreshes every undelivered, stale shipment. Suitable for a cron/admin trigger.
async function syncActiveShipments() {
  await ensureSchema();
  const { rows } = await database
    .getPool()
    .query(`${SELECT_SHIPMENTS} WHERE delivered=$1 ORDER BY last_synced_at`, [
      false,
    ]);
  const due = rows.filter(isStale);
  await syncRows(due);
  return { checked: due.length };
}

async function trackWaybill(waybill) {
  const tracking = (await fetchTracking([waybill])).get(waybill);
  if (!tracking)
    throw Object.assign(new Error("Waybill not found at Delhivery"), {
      status: 404,
      errorCode: "WAYBILL_NOT_FOUND",
    });
  return tracking;
}

// ---------------------------------------------------------------------------
// Shipment creation (order -> Delhivery AWB). Classic Delhivery B2C CMU API:
// POST {baseUrl}/api/cmu/create.json with form body
// `format=json&data={"shipments":[{...}],"pickup_location":{"name":"..."}}`
// Auth: `Authorization: Token <DELHIVERY_API_TOKEN>`.
// The AWB is assigned by Delhivery and returned as packages[0].waybill.
// ---------------------------------------------------------------------------

function shipmentConfig() {
  const base = config();
  return {
    ...base,
    pickupLocation: process.env.DELHIVERY_PICKUP_LOCATION || "",
    shippingMode:
      (process.env.DELHIVERY_SHIPPING_MODE || "SURFACE").toUpperCase() ===
      "EXPRESS"
        ? "Express"
        : "Surface",
    defaultWeightGm: Number(process.env.DELHIVERY_DEFAULT_WEIGHT_GM || 500),
    autoCreate: process.env.DELHIVERY_AUTO_CREATE_SHIPMENT !== "false",
    sellerName: process.env.DELHIVERY_SELLER_NAME || "",
    sellerAddress: process.env.DELHIVERY_SELLER_ADDRESS || "",
    sellerCity: process.env.DELHIVERY_SELLER_CITY || "",
    sellerState: process.env.DELHIVERY_SELLER_STATE || "",
    sellerPin: process.env.DELHIVERY_SELLER_PIN || "",
    sellerPhone: process.env.DELHIVERY_SELLER_PHONE || "",
  };
}

function isShipmentCreationConfigured() {
  const { token, pickupLocation } = shipmentConfig();
  return Boolean(token && pickupLocation);
}

// Adds the orders.delhivery_awb / shipment_status / shipment_error cache columns
// on first use so existing deployments need no manual migration. The detailed
// per-shipment record stays in order_shipments; these columns are a fast lookup
// + failure record for orders that have no waybill yet.
let shipmentColumnsPromise = null;
function ensureOrderShipmentColumns() {
  if (shipmentColumnsPromise) return shipmentColumnsPromise;
  const pool = database.getPool();
  const addColumn = (ddl) =>
    pool.query(ddl).catch((error) => {
      if (
        error &&
        (error.errno === 1060 || /duplicate column/i.test(error.message || ""))
      )
        return null;
      throw error;
    });
  shipmentColumnsPromise = (async () => {
    await addColumn(
      "ALTER TABLE orders ADD COLUMN delhivery_awb VARCHAR(40) NULL",
    );
    await addColumn(
      "ALTER TABLE orders ADD COLUMN shipment_status VARCHAR(20) NOT NULL DEFAULT 'PENDING'",
    );
    await addColumn("ALTER TABLE orders ADD COLUMN shipment_error TEXT NULL");
    try {
      await pool.query(
        "CREATE INDEX idx_orders_delhivery_awb ON orders(delhivery_awb)",
      );
    } catch (error) {
      if (!(
        error &&
        (error.errno === 1061 || /duplicate key/i.test(error.message || ""))
      ))
        throw error;
    }
    return true;
  })().catch((error) => {
    shipmentColumnsPromise = null;
    throw error;
  });
  return shipmentColumnsPromise;
}

const digitsOnly = (value) => String(value || "").replace(/\D/g, "");
function normalizePhone(value) {
  let digits = digitsOnly(value);
  if (digits.length === 12 && digits.startsWith("91")) digits = digits.slice(2);
  if (digits.length === 11 && digits.startsWith("0")) digits = digits.slice(1);
  return /^\d{10}$/.test(digits) ? digits : "";
}
function normalizePin(value) {
  const digits = digitsOnly(value);
  return /^\d{6}$/.test(digits) ? digits : "";
}
// Delhivery rejects names with digits/symbols; keep letters, spaces, dots.
function normalizeName(value, fallback = "Customer") {
  const cleaned = String(value || "")
    .replace(/[^A-Za-z .'-]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 50);
  return cleaned || fallback;
}
function asObject(value) {
  if (!value) return {};
  if (typeof value === "object") return value;
  try {
    const parsed = JSON.parse(value);
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch (_) {
    return {};
  }
}

// Order specifications store the address either as a plain string or as an
// object; customerDetails and the default customer_addresses row fill the gaps.
function parseConsignee({
  specifications = {},
  customerDetails = {},
  customer = {},
  defaultAddress = {},
}) {
  const specs = specifications || {};
  const details = asObject(
    customerDetails && typeof customerDetails === "object"
      ? customerDetails
      : specs.customerDetails,
  );
  const addrObj = asObject(
    typeof specs.address === "object" ? specs.address : null,
  );
  const stringAddress =
    typeof specs.address === "string" ? specs.address.trim() : "";
  const pick = (...values) =>
    values.map((v) => String(v == null ? "" : v).trim()).find((v) => v) || "";
  return {
    name: normalizeName(
      pick(
        details.name,
        details.customerName,
        customer.name,
        addrObj.name,
        addrObj.firstName,
      ),
    ),
    address:
      pick(
        addrObj.address,
        addrObj.addressLine,
        addrObj.address_line,
        addrObj.line1,
        stringAddress,
        defaultAddress.address_line,
      ).slice(0, 200) || "Address as per order",
    city: pick(addrObj.city, details.city, defaultAddress.city, "Mumbai").slice(
      0,
      50,
    ),
    state: pick(
      addrObj.state,
      details.state,
      defaultAddress.state,
      "Maharashtra",
    ).slice(0, 50),
    pin: normalizePin(
      pick(
        addrObj.pincode,
        addrObj.pincodes,
        addrObj.pin,
        addrObj.zip,
        details.pincode,
        details.pin,
        defaultAddress.pincode,
      ),
    ),
    phone: normalizePhone(
      pick(
        details.phone,
        details.mobile,
        details.phoneNumber,
        customer.mobile,
        addrObj.phone,
        addrObj.mobile,
      ),
    ),
    email: pick(details.email, customer.email),
  };
}

function buildShipmentPayload({
  orderNo,
  consignee,
  amount = 0,
  product = "Sign board",
  quantity = 1,
  weightGm,
  paymentMode = "Prepaid",
  codAmount = 0,
  shippingMode,
}) {
  const cfg = shipmentConfig();
  const weightKg = Math.max(
    0.1,
    Number(weightGm || cfg.defaultWeightGm) / 1000,
  );
  const mode = paymentMode === "COD" ? "COD" : "Prepaid";
  return {
    add: consignee.address,
    city: consignee.city,
    state: consignee.state,
    country: "India",
    name: consignee.name,
    order: String(orderNo),
    payment_mode: mode,
    cod_amount: mode === "COD" ? Number(codAmount || amount || 0) : 0,
    phone: consignee.phone,
    pin: consignee.pin,
    products_desc: String(product || "Sign board").slice(0, 100),
    quantity: Math.max(1, Number(quantity) || 1),
    total_amount: Number(amount || 0),
    weight: Number(weightKg.toFixed(2)),
    shipping_mode: shippingMode || cfg.shippingMode,
  };
}

// Inspects the complete CMU response and safely extracts the assigned waybill.
// Never assume a single shape: success variants include
// {packages:[{waybill,status}]}, {success:true,waybill}, {wbns:[...]}.
function extractWaybill(body) {
  if (!body || typeof body !== "object") return null;
  const packages = Array.isArray(body.packages) ? body.packages : [];
  for (const pkg of packages) {
    const waybill = digitsOnly(pkg && (pkg.waybill || pkg.awb || pkg.wbn));
    const status = String(
      (pkg && (pkg.status || pkg.remarks)) || "",
    ).toLowerCase();
    const ok =
      !status || /success|manifest|manifested|created|ok|true/.test(status);
    if (waybill && waybill.length >= 6 && ok) return waybill;
  }
  const direct = digitsOnly(body.waybill || body.awb || body.wbn);
  if (direct && direct.length >= 6) return direct;
  if (Array.isArray(body.wbns) && body.wbns[0]) {
    const first = digitsOnly(body.wbns[0]);
    if (first.length >= 6) return first;
  }
  if (body.data && typeof body.data === "object")
    return extractWaybill(body.data);
  return null;
}

function extractShipmentError(body) {
  if (!body || typeof body !== "object") return "";
  if (typeof body.error === "string") return body.error.slice(0, 500);
  if (
    typeof body.message === "string" &&
    /fail|error|invalid/i.test(body.message)
  )
    return body.message.slice(0, 500);
  const pkg = Array.isArray(body.packages) ? body.packages[0] : null;
  if (pkg && typeof pkg === "object") {
    const remark = String(
      pkg.remarks || pkg.remark || pkg.error || pkg.status || "",
    ).trim();
    if (remark && !/success|manifested|created/i.test(remark))
      return remark.slice(0, 500);
  }
  return "";
}

async function createDelhiveryShipment(shipment, { pickupLocation } = {}) {
  const { token, baseUrl, timeoutMs } = shipmentConfig();
  if (!token)
    throw Object.assign(
      new Error(
        "Delhivery shipment creation is not configured (missing API token)",
      ),
      { status: 503, errorCode: "DELHIVERY_NOT_CONFIGURED" },
    );
  const pickup = pickupLocation || shipmentConfig().pickupLocation;
  if (!pickup)
    throw Object.assign(
      new Error("Delhivery shipment creation needs DELHIVERY_PICKUP_LOCATION"),
      { status: 503, errorCode: "DELHIVERY_PICKUP_MISSING" },
    );
  const payload = { shipments: [shipment], pickup_location: { name: pickup } };
  const form = `format=json&data=${encodeURIComponent(JSON.stringify(payload))}`;
  let response;
  try {
    response = await fetch(`${baseUrl}/api/cmu/create.json`, {
      method: "POST",
      headers: {
        Authorization: `Token ${token}`,
        "Content-Type": "application/x-www-form-urlencoded",
        Accept: "application/json",
      },
      body: form,
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch (error) {
    throw Object.assign(
      new Error("Delhivery shipment service is unreachable"),
      { status: 502, errorCode: "DELHIVERY_UNREACHABLE", cause: error },
    );
  }
  if (response.status === 401 || response.status === 403)
    throw Object.assign(new Error("Delhivery rejected the API token"), {
      status: 502,
      errorCode: "DELHIVERY_AUTH_FAILED",
    });
  const body = await response.json().catch(() => ({}));
  if (!response.ok)
    throw Object.assign(
      new Error(
        `Delhivery shipment creation failed with HTTP ${response.status}`,
      ),
      { status: 502, errorCode: "DELHIVERY_ERROR", responseBody: body },
    );
  const waybill = extractWaybill(body);
  if (!waybill)
    throw Object.assign(
      new Error(extractShipmentError(body) || "Delhivery returned no waybill"),
      { status: 502, errorCode: "DELHIVERY_NO_WAYBILL", responseBody: body },
    );
  return { waybill, raw: body };
}

async function markShipmentState(
  orderDatabaseId,
  { awb = null, status, error = null },
) {
  try {
    await ensureOrderShipmentColumns();
    await database
      .getPool()
      .query(
        "UPDATE orders SET delhivery_awb=COALESCE($1,delhivery_awb),shipment_status=$2,shipment_error=$3,updated_at=NOW() WHERE id=$4",
        [awb, status, error, orderDatabaseId],
      );
  } catch (columnsError) {
    console.error(
      "[DELHIVERY] Could not persist shipment state:",
      columnsError.message,
    );
  }
}

// Fire-and-forget so SMTP latency and outages never delay or fail the order
// response. orderEmailService never rejects, but the guard keeps a broken
// import from becoming an unhandled rejection.
function notifyAwbEmail(orderDatabaseId, waybill) {
  return require("./orderEmailService")
    .queueAwbEmail(orderDatabaseId, waybill)
    .then((result) => {
      if (result && result.status !== "skipped")
        console.log(
          `[EMAIL] AWB email ${result.status} for order ${orderDatabaseId} (${waybill})`,
        );
    })
    .catch((error) =>
      console.error(
        `[EMAIL] AWB email for order ${orderDatabaseId} failed:`,
        error.message,
      ),
    );
}

// Idempotent auto-creation for one order (looked up by order_no, the same
// reference sent to Delhivery). Never throws: failures are recorded on the
// order as FAILED/PENDING and returned, so order creation is never lost.
async function ensureShipmentForOrder(orderNo, { userId = null } = {}) {
  await ensureSchema();
  await ensureOrderShipmentColumns();
  const pool = database.getPool();
  const orderRow = (
    await pool.query(
      "SELECT o.id,o.order_no,o.customer_id,o.specifications,o.estimated_price,o.delhivery_awb FROM orders o WHERE o.order_no=$1",
      [orderNo],
    )
  ).rows[0];
  if (!orderRow)
    return {
      success: false,
      errorCode: "ORDER_NOT_FOUND",
      message: "Order not found",
    };
  const existingShipment = (
    await pool.query(
      "SELECT waybill FROM order_shipments WHERE order_id=$1 ORDER BY id DESC LIMIT 1",
      [orderRow.id],
    )
  ).rows[0];
  const existingAwb =
    (existingShipment && existingShipment.waybill) ||
    orderRow.delhivery_awb ||
    null;
  if (existingAwb) {
    console.log(
      `[DELHIVERY] Shipment already exists for order ${orderNo}, reusing AWB`,
    );
    await markShipmentState(orderRow.id, {
      awb: String(existingAwb),
      status: "CREATED",
      error: null,
    });
    // A previous run may have saved the waybill but lost the email; queueing is
    // idempotent, so an already-delivered AWB mail is not sent twice.
    notifyAwbEmail(orderRow.id, String(existingAwb));
    return {
      success: true,
      waybill: String(existingAwb),
      existing: true,
      shipmentStatus: "CREATED",
    };
  }
  if (!shipmentConfig().autoCreate) {
    await markShipmentState(orderRow.id, {
      status: "PENDING",
      error: "Auto shipment creation is disabled",
    });
    return {
      success: false,
      errorCode: "AUTO_CREATE_DISABLED",
      message: "Auto shipment creation is disabled",
      shipmentStatus: "PENDING",
    };
  }
  const customer =
    (
      await pool.query(
        "SELECT c.id,u.name,u.email,u.mobile FROM customers c JOIN users u ON u.id=c.user_id WHERE c.id=$1",
        [orderRow.customer_id],
      )
    ).rows[0] || {};
  const defaultAddress =
    (
      await pool.query(
        "SELECT address_line,city,state,pincode FROM customer_addresses WHERE customer_id=$1 ORDER BY is_default DESC,id DESC LIMIT 1",
        [orderRow.customer_id],
      )
    ).rows[0] || {};
  const specs = orderRow.specifications || {};
  const consignee = parseConsignee({
    specifications: specs,
    customerDetails: specs.customerDetails,
    customer,
    defaultAddress,
  });
  if (!consignee.pin) {
    const message =
      "Cannot create Delhivery shipment: customer PIN code is missing or invalid (6 digits required)";
    console.error(`[DELHIVERY] ${message} for order ${orderNo}`);
    await markShipmentState(orderRow.id, { status: "FAILED", error: message });
    return {
      success: false,
      errorCode: "MISSING_PINCODE",
      message,
      shipmentStatus: "FAILED",
    };
  }
  if (!consignee.phone) {
    const message =
      "Cannot create Delhivery shipment: customer phone number is missing or invalid (10 digits required)";
    console.error(`[DELHIVERY] ${message} for order ${orderNo}`);
    await markShipmentState(orderRow.id, { status: "FAILED", error: message });
    return {
      success: false,
      errorCode: "MISSING_PHONE",
      message,
      shipmentStatus: "FAILED",
    };
  }
  if (!isShipmentCreationConfigured()) {
    const message =
      "Delhivery shipment creation is not configured (set DELHIVERY_API_TOKEN and DELHIVERY_PICKUP_LOCATION)";
    console.error(`[DELHIVERY] ${message}; order ${orderNo} kept as PENDING`);
    await markShipmentState(orderRow.id, { status: "PENDING", error: message });
    return {
      success: false,
      errorCode: "DELHIVERY_NOT_CONFIGURED",
      message,
      shipmentStatus: "PENDING",
    };
  }
  const shipment = buildShipmentPayload({
    orderNo,
    consignee,
    amount: Number(orderRow.estimated_price || specs.finalEstimatedPrice || 0),
    product: specs.product || "Sign board",
    quantity: specs.quantity || 1,
    weightGm: specs.weightGm || specs.weight,
  });
  console.log(
    `[DELHIVERY] Creating shipment for order ${orderNo} (pin ${consignee.pin})...`,
  );
  try {
    const { waybill, raw } = await createDelhiveryShipment(shipment);
    console.log(
      `[DELHIVERY] Shipment creation response received for order ${orderNo}`,
    );
    console.log(`[DELHIVERY] Waybill: ${waybill}`);
    const duplicate = (
      await pool.query(
        "SELECT order_id FROM order_shipments WHERE waybill=$1",
        [waybill],
      )
    ).rows[0];
    if (duplicate && Number(duplicate.order_id) !== Number(orderRow.id)) {
      throw Object.assign(
        new Error(
          "Delhivery returned a waybill already linked to another order",
        ),
        { status: 409, errorCode: "WAYBILL_IN_USE" },
      );
    }
    if (!duplicate) {
      await pool.query(
        "INSERT INTO order_shipments(order_id,provider,waybill,status,created_by) VALUES($1,'delhivery',$2,'Manifested',$3)",
        [orderRow.id, waybill, userId],
      );
    }
    if (isEnabled()) {
      try {
        const row = (
          await pool.query("SELECT * FROM order_shipments WHERE waybill=$1", [
            waybill,
          ])
        ).rows[0];
        if (row) await syncRows([row]);
      } catch (syncError) {
        console.error(
          "[DELHIVERY] Post-creation tracking sync failed:",
          syncError.message,
        );
      }
    }
    await markShipmentState(orderRow.id, {
      awb: waybill,
      status: "CREATED",
      error: null,
    });
    console.log(`[ORDER] AWB saved successfully for order ${orderNo}`);
    notifyAwbEmail(orderRow.id, waybill);
    return { success: true, waybill, shipmentStatus: "CREATED", response: raw };
  } catch (error) {
    const retryable = [
      "DELHIVERY_UNREACHABLE",
      "DELHIVERY_ERROR",
      "DELHIVERY_NOT_CONFIGURED",
    ].includes(error.errorCode);
    const status = retryable ? "PENDING" : "FAILED";
    console.error(
      `[DELHIVERY] Shipment creation failed for order ${orderNo}:`,
      error.message,
    );
    await markShipmentState(orderRow.id, {
      status,
      error: String(error.message || "Shipment creation failed").slice(0, 500),
    });
    return {
      success: false,
      errorCode: error.errorCode || "DELHIVERY_ERROR",
      message: error.message,
      shipmentStatus: status,
    };
  }
}

async function getOrderShipmentState(orderDatabaseId) {
  await ensureSchema();
  const pool = database.getPool();
  const [shipments, orderCols] = await Promise.all([
    pool.query(
      "SELECT waybill FROM order_shipments WHERE order_id=$1 ORDER BY id DESC LIMIT 1",
      [orderDatabaseId],
    ),
    ensureOrderShipmentColumns()
      .then(() =>
        pool.query(
          "SELECT delhivery_awb,shipment_status FROM orders WHERE id=$1",
          [orderDatabaseId],
        ),
      )
      .catch(() => ({ rows: [] })),
  ]);
  const waybill =
    (shipments.rows[0] && shipments.rows[0].waybill) ||
    (orderCols.rows[0] && orderCols.rows[0].delhivery_awb) ||
    null;
  const shipmentStatus =
    (orderCols.rows[0] && orderCols.rows[0].shipment_status) ||
    (waybill ? "CREATED" : "PENDING");
  return { delhiveryAwb: waybill ? String(waybill) : null, shipmentStatus };
}

module.exports = {
  isEnabled,
  stageOf,
  normalizeShipment,
  fetchTracking,
  listOrderShipments,
  addShipment,
  removeShipment,
  syncActiveShipments,
  trackWaybill,
  shipmentConfig,
  isShipmentCreationConfigured,
  parseConsignee,
  buildShipmentPayload,
  extractWaybill,
  createDelhiveryShipment,
  ensureShipmentForOrder,
  getOrderShipmentState,
  ensureOrderShipmentColumns,
  publicTrackingUrl,
};
