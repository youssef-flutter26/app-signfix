const database = require("../database");
const { businessId } = require("../utils/ids");
const delhivery = require("../services/delhiveryService");
async function list(req, res) {
  const data = await database.listOrders(req.user, req.query);
  res.json({ data, page: Number(req.query.page || 1), total: data.length });
}

async function create(req, res) {
  const orderNo = businessId("SB-ORD");
  console.log(`[ORDER] Creating order: ${orderNo}`);
  const order = await database.createOrder(req.user, req.body, orderNo);
  console.log(`[ORDER] Order created: ${order.id}`);
  let shipment = {
    success: false,
    waybill: null,
    shipmentStatus: "PENDING",
    message: null,
  };
  try {
    console.log("[DELHIVERY] Creating shipment...");
    shipment = await delhivery.ensureShipmentForOrder(order.id, {
      userId: req.user.id,
    });
  } catch (error) {
    console.error(
      "[DELHIVERY] Shipment step failed without losing the order:",
      error.message,
    );
    shipment = {
      success: false,
      waybill: null,
      shipmentStatus: "FAILED",
      message: error.message,
    };
  }
  const created = shipment.success && shipment.waybill;
  res.status(201).json({
    ...order,
    delhiveryAwb: created ? shipment.waybill : null,
    shipmentStatus:
      shipment.shipmentStatus || (created ? "CREATED" : "PENDING"),
    ...(shipment.message && !created
      ? { shipmentError: shipment.message }
      : {}),
  });
}
async function detail(req, res) {
  const order = await database.getOrder(req.params.id, req.user),
    pool = database.getPool();
  const [payments, services, statusHistory, shipmentState] = await Promise.all([
    pool.query(
      `SELECT p.id,p.amount,p.status,p.reference,p.provider,p.created_at AS "createdAt" FROM payments p LEFT JOIN quotations q ON q.id=p.quotation_id WHERE COALESCE(p.order_id,q.order_id)=$1 ORDER BY p.id DESC`,
      [order.databaseId],
    ),
    pool.query(
      `SELECT s.ticket_no AS "ticketNo",s.status,j.id AS "jobId",j.status AS "jobStatus",tu.name AS technician FROM service_tickets s LEFT JOIN technician_jobs j ON j.ticket_id=s.id LEFT JOIN technicians t ON t.id=j.technician_id LEFT JOIN users tu ON tu.id=t.user_id WHERE s.order_id=$1 ORDER BY s.id DESC`,
      [order.databaseId],
    ),
    pool.query(
      `SELECT status,notes,created_at AS "createdAt" FROM order_status_history WHERE order_id=$1 ORDER BY created_at`,
      [order.databaseId],
    ),
    delhivery
      .getOrderShipmentState(order.databaseId)
      .catch(() => ({ delhiveryAwb: null, shipmentStatus: "PENDING" })),
  ]);
  res.json({
    ...order,
    delhiveryAwb: shipmentState.delhiveryAwb,
    shipmentStatus: shipmentState.shipmentStatus,
    payments: payments.rows,
    services: services.rows,
    statusHistory: statusHistory.rows,
  });
}
async function update(req, res) {
  res.json(await database.updateOrder(req.params.id, req.body, req.user));
}
async function updateStatus(req, res) {
  res.json(
    await database.updateOrderStatus(req.params.id, req.body.status, req.user),
  );
}
async function reviewDesign(req, res) {
  res.json(
    await database.reviewOrderDesign(
      req.params.id,
      req.params.designId,
      req.body,
      req.user,
    ),
  );
}
async function whatsappLogs(req, res) {
  const limit = Math.min(Number(req.query.limit) || 50, 200);
  const { rows } = await database
    .getPool()
    .query(
      `SELECT w.id,o.order_no AS "orderNo",u.name AS customer,w.event_key AS "eventKey",w.recipient,w.message,w.status,w.provider_message_id AS "providerMessageId",w.error_message AS "errorMessage",w.attempted_at AS "attemptedAt",w.created_at AS "createdAt" FROM order_whatsapp_logs w JOIN orders o ON o.id=w.order_id LEFT JOIN users u ON u.id=w.customer_user_id ORDER BY w.created_at DESC LIMIT $1`,
      [limit],
    );
  res.json({ data: rows });
}
async function emailLogs(req, res) {
  const limit = Math.min(Number(req.query.limit) || 50, 200);
  const { rows } = await database
    .getPool()
    .query(
      `SELECT e.id,o.order_no AS "orderNo",u.name AS customer,e.event_key AS "eventKey",e.recipient,e.subject,e.status,e.provider_message_id AS "providerMessageId",e.error_message AS "errorMessage",e.attempted_at AS "attemptedAt",e.created_at AS "createdAt" FROM order_email_logs e JOIN orders o ON o.id=e.order_id LEFT JOIN users u ON u.id=e.customer_user_id ORDER BY e.created_at DESC LIMIT $1`,
      [limit],
    );
  res.json({ data: rows });
}
// Customers get cached tracking (refreshed when stale); staff may force a refresh.
// `waybill` mirrors the latest AWB for convenience; `shipments` is unchanged.
async function tracking(req, res) {
  const order = await database.getOrder(req.params.id, req.user);
  const refresh =
    req.user.role !== "customer" && String(req.query.refresh) === "true";
  const shipments = await delhivery.listOrderShipments(order.databaseId, {
    refresh,
  });
  const waybill = shipments.length ? shipments[0].waybill : null;
  if (!waybill)
    return res.json({
      success: false,
      message: "Delhivery shipment has not been created for this order",
      orderNo: order.id,
      orderId: order.id,
      orderStatus: order.status,
      waybill: null,
      status: null,
      tracking: [],
      shipments,
    });
  const primary = shipments[0];
  res.json({
    success: true,
    orderNo: order.id,
    orderId: order.id,
    orderStatus: order.status,
    waybill,
    status: primary.status,
    tracking: primary.scans || [],
    shipments,
  });
}
async function addShipment(req, res) {
  const order = await database.getOrder(req.params.id, req.user);
  res
    .status(201)
    .json(
      await delhivery.addShipment(
        order.databaseId,
        req.body.waybill,
        req.user.id,
      ),
    );
}
async function removeShipment(req, res) {
  const order = await database.getOrder(req.params.id, req.user);
  await delhivery.removeShipment(order.databaseId, req.params.waybill);
  res.status(204).end();
}
module.exports = {
  list,
  create,
  detail,
  update,
  updateStatus,
  reviewDesign,
  whatsappLogs,
  emailLogs,
  tracking,
  addShipment,
  removeShipment,
};
