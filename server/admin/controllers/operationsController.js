const db = require("../../database"),
  bcrypt = require("bcryptjs"),
  crypto = require("crypto");
const { businessId } = require("../../utils/ids");
const pool = () => db.getPool();
async function tickets(req, res) {
  const p = [],
    w = [];
  if (req.query.status) {
    p.push(req.query.status);
    w.push(`s.status=$${p.length}`);
  }
  if (req.query.priority) {
    p.push(req.query.priority);
    w.push(`s.priority=$${p.length}`);
  }
  if (req.query.search) {
    p.push(`%${req.query.search}%`);
    w.push(
      `(LOWER(s.ticket_no) LIKE LOWER($${p.length}) OR LOWER(u.name) LIKE LOWER($${p.length}) OR LOWER(s.description) LIKE LOWER($${p.length}))`,
    );
  }
  const { rows } = await pool().query(
    `SELECT s.ticket_no AS id,u.name AS customer,s.location,s.description AS issue,s.photos,s.priority,tu.name AS technician,s.status,s.created_at AS "createdAt" FROM service_tickets s JOIN customers c ON c.id=s.customer_id JOIN users u ON u.id=c.user_id LEFT JOIN technician_jobs j ON j.ticket_id=s.id LEFT JOIN technicians t ON t.id=j.technician_id LEFT JOIN users tu ON tu.id=t.user_id ${w.length ? "WHERE " + w.join(" AND ") : ""} ORDER BY s.id DESC`,
    p,
  );
  res.json({ data: rows, total: rows.length });
}
async function ticket(req, res) {
  const row = (
    await pool().query(
      `SELECT s.id AS "databaseId",s.ticket_no AS id,u.name AS customer,s.location,s.description AS issue,s.category,s.photos,s.priority,s.status,s.admin_notes AS "adminNotes",a.asset_no AS "assetNo",j.id AS "jobId",j.technician_id AS "technicianId",tu.name AS technician,s.created_at AS "createdAt" FROM service_tickets s JOIN customers c ON c.id=s.customer_id JOIN users u ON u.id=c.user_id LEFT JOIN sign_board_assets a ON a.id=s.asset_id LEFT JOIN technician_jobs j ON j.ticket_id=s.id LEFT JOIN technicians t ON t.id=j.technician_id LEFT JOIN users tu ON tu.id=t.user_id WHERE s.ticket_no=$1`,
      [req.params.id],
    )
  ).rows[0];
  if (!row) throw Object.assign(new Error("Ticket not found"), { status: 404 });
  const [technicians, history, evidence] = await Promise.all([
    pool().query(
      "SELECT t.id,u.name,u.mobile FROM technicians t JOIN users u ON u.id=t.user_id WHERE u.status='active' ORDER BY u.name",
    ),
    row.jobId
      ? pool().query(
          'SELECT status,notes,created_at AS "createdAt" FROM job_status_history WHERE job_id=$1 ORDER BY id',
          [row.jobId],
        )
      : Promise.resolve({ rows: [] }),
    row.jobId
      ? pool().query(
          'SELECT id,photo_type AS "photoType",storage_key AS "storageKey",mime_type AS "mimeType",created_at AS "createdAt" FROM job_photos WHERE job_id=$1 ORDER BY id',
          [row.jobId],
        )
      : Promise.resolve({ rows: [] }),
  ]);
  row.technicians = technicians.rows;
  row.history = history.rows;
  row.evidence = evidence.rows;
  res.json(row);
}
async function updateTicket(req, res) {
  const client = await pool().connect(),
    hasTechnician = Object.prototype.hasOwnProperty.call(
      req.body,
      "technicianId",
    );
  try {
    await client.query("BEGIN");
    const t = (
      await client.query(
        "SELECT id,customer_id FROM service_tickets WHERE ticket_no=$1",
        [req.params.id],
      )
    ).rows[0];
    if (!t) throw Object.assign(new Error("Ticket not found"), { status: 404 });
    if (req.body.technicianId) {
      const active = (
        await client.query(
          "SELECT user_id FROM technicians t JOIN users u ON u.id=t.user_id WHERE t.id=$1 AND u.status='active'",
          [req.body.technicianId],
        )
      ).rows[0];
      if (!active)
        throw Object.assign(new Error("Active technician not found"), {
          status: 422,
        });
    }
    await client.query(
      "UPDATE service_tickets SET priority=COALESCE($2,priority),admin_notes=COALESCE($3,admin_notes),status=COALESCE($4,status),updated_at=NOW() WHERE id=$1",
      [t.id, req.body.priority, req.body.adminNotes, req.body.status],
    );
    if (hasTechnician) {
      const job = (
        await client.query(
          "SELECT id,technician_id FROM technician_jobs WHERE ticket_id=$1 FOR UPDATE",
          [t.id],
        )
      ).rows[0];
      const changed =
        Number(job?.technician_id || 0) !== Number(req.body.technicianId || 0);
      if (job)
        await client.query(
          "UPDATE technician_jobs SET technician_id=$2,status=CASE WHEN $2 IS NULL THEN 'unassigned' WHEN $3 THEN 'assigned' ELSE status END,scheduled_at=COALESCE(scheduled_at,NOW()),updated_at=NOW() WHERE id=$1",
          [job.id, req.body.technicianId, changed],
        );
      else if (req.body.technicianId)
        await client.query(
          "INSERT INTO technician_jobs(ticket_id,technician_id,status,scheduled_at) VALUES($1,$2,'assigned',NOW())",
          [t.id, req.body.technicianId],
        );
      await client.query(
        "UPDATE service_tickets SET status=$2,updated_at=NOW() WHERE id=$1",
        [t.id, req.body.technicianId ? "technician_assigned" : "unassigned"],
      );
      if (changed && req.body.technicianId)
        await client.query(
          `INSERT INTO notifications(user_id,channel,title,body,event_key,data) SELECT user_id,'push','New job assigned',$2,'technician.job_assigned',$3 FROM technicians WHERE id=$1`,
          [
            req.body.technicianId,
            `Service ${req.params.id} has been assigned to you.`,
            JSON.stringify({ ticketNo: req.params.id }),
          ],
        );
    }
    const uid = (
      await client.query("SELECT user_id FROM customers WHERE id=$1", [
        t.customer_id,
      ])
    ).rows[0]?.user_id;
    await client.query("COMMIT");
    if (req.body.technicianId)
      await require("../../services/notificationService").sendEvent(
        uid,
        "service.technician_assigned",
        "Technician assigned",
        `A technician has been assigned to service ${req.params.id}.`,
        { ticketNo: req.params.id },
      );
    res.json({
      id: req.params.id,
      status: hasTechnician
        ? req.body.technicianId
          ? "technician_assigned"
          : "unassigned"
        : req.body.status || "updated",
    });
  } catch (e) {
    await client.query("ROLLBACK");
    throw e;
  } finally {
    client.release();
  }
}
async function technicians(req, res) {
  const { rows } = await pool().query(
    `SELECT t.id,u.name,u.email,u.mobile,u.status,t.service_areas AS "serviceAreas",COUNT(j.id) assigned,COUNT(CASE WHEN j.status='accepted' THEN 1 END) accepted,COUNT(CASE WHEN j.status IN ('completed','closed') THEN 1 END) completed,ROUND(AVG(CASE WHEN j.accepted_at IS NOT NULL AND (j.closed_at IS NOT NULL OR j.work_completed_at IS NOT NULL) THEN TIMESTAMPDIFF(SECOND,j.accepted_at,COALESCE(j.closed_at,j.work_completed_at))/3600 END),1) AS "averageCompletionHours",ROUND(AVG(r.rating),1) AS rating FROM technicians t JOIN users u ON u.id=t.user_id LEFT JOIN technician_jobs j ON j.technician_id=t.id LEFT JOIN reviews r ON r.job_id=j.id GROUP BY t.id,u.id ORDER BY u.name`,
  );
  res.json({ data: rows, total: rows.length });
}
async function createTechnician(req, res) {
  const client = await pool().connect();
  try {
    await client.query("BEGIN");
    const role = (
        await client.query("SELECT id FROM roles WHERE name='technician'")
      ).rows[0],
      hash = await bcrypt.hash(req.body.password, 10),
      u = {
        id: (
          await client.query(
            "INSERT INTO users(role_id,name,email,mobile,password_hash) VALUES($1,$2,LOWER($3),$4,$5)",
            [role.id, req.body.name, req.body.email, req.body.mobile, hash],
          )
        ).insertId,
      },
      t = {
        id: (
        await client.query(
          "INSERT INTO technicians(user_id,service_areas,skills) VALUES($1,$2,$3)",
          [
            u.id,
            JSON.stringify(req.body.serviceAreas),
            JSON.stringify(req.body.skills),
          ],
        )
        ).insertId,
      };
    await client.query("COMMIT");
    res.status(201).json(t);
  } catch (e) {
    await client.query("ROLLBACK");
    if (e.code === "ER_DUP_ENTRY")
      throw Object.assign(new Error("Technician email already exists"), {
        status: 409,
      });
    throw e;
  } finally {
    client.release();
  }
}
async function technician(req, res) {
  const base = (
    await pool().query(
      `SELECT t.id,t.user_id AS "userId",u.name,u.email,u.mobile,u.status,t.service_areas AS "serviceAreas",t.skills FROM technicians t JOIN users u ON u.id=t.user_id WHERE t.id=$1`,
      [req.params.id],
    )
  ).rows[0];
  if (!base)
    throw Object.assign(new Error("Technician not found"), { status: 404 });
  const [jobs, history, reviews] = await Promise.all([
    pool().query(
      `SELECT j.id,s.ticket_no AS "ticketId",s.category,s.priority,j.status,j.scheduled_at AS "scheduledAt",j.closed_at AS "closedAt" FROM technician_jobs j JOIN service_tickets s ON s.id=j.ticket_id WHERE j.technician_id=$1 ORDER BY j.id DESC`,
      [req.params.id],
    ),
    pool().query(
      `SELECT h.job_id,h.status,h.notes,h.created_at AS "createdAt" FROM job_status_history h JOIN technician_jobs j ON j.id=h.job_id WHERE j.technician_id=$1 ORDER BY h.id`,
      [req.params.id],
    ),
    pool().query(
      `SELECT r.job_id,r.rating,r.comment,r.created_at AS "createdAt" FROM reviews r JOIN technician_jobs j ON j.id=r.job_id WHERE j.technician_id=$1`,
      [req.params.id],
    ),
  ]);
  base.jobs = jobs.rows.map((job) => ({
    ...job,
    history: history.rows.filter((h) => h.job_id === job.id).map(({ job_id, ...h }) => h),
    review: (({ job_id, ...r }) => r)(reviews.rows.find((r) => r.job_id === job.id) || {}),
  }));
  for (const job of base.jobs) if (!Object.keys(job.review).length) job.review = null;
  res.json(base);
}
async function updateTechnician(req, res) {
  const cur = await technicianValue(req.params.id),
    b = req.body;
  await pool().query(
    "UPDATE users SET name=COALESCE($2,name),mobile=COALESCE($3,mobile),status=COALESCE($4,status),updated_at=NOW() WHERE id=$1",
    [cur.userId, b.name, b.mobile, b.status],
  );
  await pool().query(
    "UPDATE technicians SET service_areas=COALESCE($2,service_areas),skills=COALESCE($3,skills) WHERE id=$1",
    [
      req.params.id,
      b.serviceAreas ? JSON.stringify(b.serviceAreas) : null,
      b.skills ? JSON.stringify(b.skills) : null,
    ],
  );
  res.json(await technicianValue(req.params.id));
}
async function technicianValue(id) {
  return (
    (
      await pool().query(
        'SELECT t.id,t.user_id AS "userId",u.name,u.email,u.mobile,u.status,t.service_areas AS "serviceAreas",t.skills FROM technicians t JOIN users u ON u.id=t.user_id WHERE t.id=$1',
        [id],
      )
    ).rows[0] ||
    (() => {
      throw Object.assign(new Error("Technician not found"), { status: 404 });
    })()
  );
}
async function assets(req, res) {
  const { rows } = await pool().query(
    `SELECT a.asset_no AS "assetNo",u.name AS customer,o.order_no AS "orderNo",a.location,JSON_UNQUOTE(JSON_EXTRACT(a.details,'$.signType')) AS "signType",JSON_UNQUOTE(JSON_EXTRACT(a.details,'$.size')) AS size,a.installation_date AS "installationDate",a.warranty_start AS "warrantyStart",a.warranty_until AS "warrantyUntil",a.status,a.created_at AS "createdAt" FROM sign_board_assets a JOIN customers c ON c.id=a.customer_id JOIN users u ON u.id=c.user_id LEFT JOIN orders o ON o.id=a.order_id ORDER BY a.id DESC`,
  );
  res.json({ data: rows, total: rows.length });
}
async function createAsset(req, res) {
  const no = businessId("SB-AST"),
    token = crypto.randomBytes(32).toString("hex"),
    b = req.body,
    details = { signType: b.signType, size: b.size, material: b.material },
    client = await pool().connect();
  try {
    await client.query("BEGIN");
    let orderId=null;
    if(b.orderNo){const order=(await client.query('SELECT id FROM orders WHERE order_no=$1 AND customer_id=$2',[b.orderNo,b.customerId])).rows[0];if(!order)throw Object.assign(new Error('Order does not belong to the selected customer'),{status:422});orderId=order.id;}
    const warrantyStart=b.warrantyStart||b.installationDate;
    if(b.warrantyUntil&&new Date(b.warrantyUntil)<new Date(warrantyStart))throw Object.assign(new Error('Warranty expiry must be on or after the warranty start date'),{status:422});
    const inserted = (
      await client.query(
        'INSERT INTO sign_board_assets(asset_no,customer_id,order_id,details,location,installation_date,warranty_start,warranty_until,status,photos,qr_token) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)',
        [
          no,
          b.customerId,
          orderId,
          JSON.stringify(details),
          JSON.stringify(b.location),
          b.installationDate,
          warrantyStart,
          b.warrantyUntil,
          b.status||'active',
          JSON.stringify(b.photos),
          token,
        ],
      )
    ).insertId;
    const row = { id: inserted, assetNo: no, qrToken: token, status: b.status || 'active' };
    await client.query(
      "INSERT INTO qr_codes(asset_id,token,active) VALUES($1,$2,TRUE)",
      [row.id, token],
    );
    await client.query("INSERT INTO audit_logs(user_id,action,entity_type,entity_id,metadata) VALUES($1,'asset.created','sign_board_asset',$2,$3)",[req.user.id,row.id,JSON.stringify({assetNo:no,customerId:b.customerId,orderNo:b.orderNo||null})]);
    await client.query("COMMIT");
    delete row.id;
    res.status(201).json(row);
  } catch (e) {
    await client.query("ROLLBACK");
    throw e;
  } finally {
    client.release();
  }
}
async function asset(req, res) {
  const row = (
    await pool().query(
      `SELECT a.id,a.asset_no AS "assetNo",a.customer_id AS "customerId",u.name AS customer,a.location,a.details,a.installation_date AS "installationDate",a.warranty_until AS "warrantyUntil",a.photos,a.qr_token AS "qrToken" FROM sign_board_assets a JOIN customers c ON c.id=a.customer_id JOIN users u ON u.id=c.user_id WHERE a.asset_no=$1`,
      [req.params.id],
    )
  ).rows[0];
  if (!row) throw Object.assign(new Error("Asset not found"), { status: 404 });
  row.history = (
    await pool().query(
      'SELECT h.id,h.history_type AS type,h.notes,s.ticket_no AS "ticketId",h.created_at AS "createdAt" FROM asset_service_history h LEFT JOIN service_tickets s ON s.id=h.ticket_id WHERE h.asset_id=$1 ORDER BY h.id DESC',
      [row.id],
    )
  ).rows;
  const extra=(await pool().query('SELECT a.warranty_start AS "warrantyStart",a.status,o.order_no AS "orderNo",q.active AS "qrActive" FROM sign_board_assets a LEFT JOIN orders o ON o.id=a.order_id LEFT JOIN qr_codes q ON q.asset_id=a.id WHERE a.id=$1',[row.id])).rows[0];
  Object.assign(row,extra,{warrantyActive:Boolean(extra&&row.warrantyUntil&&new Date(row.warrantyUntil)>=new Date()&&extra.status!=='retired')});
  res.json(row);
}
async function updateAsset(req, res) {
  const b = req.body,
    details = { signType: b.signType, size: b.size, material: b.material };
  const { rowCount } = await pool().query(
    'UPDATE sign_board_assets SET location=COALESCE($2,location),details=JSON_MERGE_PATCH(COALESCE(details,JSON_OBJECT()),$3),installation_date=COALESCE($4,installation_date),warranty_start=COALESCE($5,warranty_start),warranty_until=COALESCE($6,warranty_until),status=COALESCE($7,status),photos=COALESCE($8,photos) WHERE asset_no=$1',
    [
      req.params.id,
      b.location ? JSON.stringify(b.location) : null,
      JSON.stringify(
        Object.fromEntries(
          Object.entries(details).filter(([, v]) => v !== undefined),
        ),
      ),
      b.installationDate,
      b.warrantyStart,
      b.warrantyUntil,
      b.status,
      b.photos ? JSON.stringify(b.photos) : null,
    ],
  );
  const rows = rowCount ? [{ assetNo: req.params.id }] : [];
  if (!rows[0])
    throw Object.assign(new Error("Asset not found"), { status: 404 });
  res.json(rows[0]);
}
async function updateAssetQr(req,res){const client=await pool().connect();try{await client.query('BEGIN');const asset=(await client.query('SELECT id,qr_token FROM sign_board_assets WHERE asset_no=$1 FOR UPDATE',[req.params.id])).rows[0];if(!asset)throw Object.assign(new Error('Asset not found'),{status:404});let token=asset.qr_token;if(req.body.action==='rotate'){token=crypto.randomBytes(32).toString('hex');await client.query('UPDATE sign_board_assets SET qr_token=$2 WHERE id=$1',[asset.id,token]);await client.query('INSERT INTO qr_codes(asset_id,token,active) VALUES($1,$2,TRUE) ON DUPLICATE KEY UPDATE token=VALUES(token),active=TRUE,created_at=NOW()',[asset.id,token]);}else await client.query('UPDATE qr_codes SET active=$2 WHERE asset_id=$1',[asset.id,req.body.action==='enable']);await client.query("INSERT INTO audit_logs(user_id,action,entity_type,entity_id,metadata) VALUES($1,$2,'sign_board_asset',$3,$4)",[req.user.id,`asset.qr.${req.body.action}`,asset.id,JSON.stringify({assetNo:req.params.id})]);await client.query('COMMIT');res.json({assetNo:req.params.id,qrToken:token,qrActive:req.body.action!=='disable'});}catch(e){await client.query('ROLLBACK');throw e;}finally{client.release();}}
async function addAssetHistory(req, res) {
  const asset = (
    await pool().query("SELECT id FROM sign_board_assets WHERE asset_no=$1", [
      req.params.id,
    ])
  ).rows[0];
  if (!asset)
    throw Object.assign(new Error("Asset not found"), { status: 404 });
  const { insertId } = await pool().query(
    'INSERT INTO asset_service_history(asset_id,ticket_id,history_type,notes) VALUES($1,$2,$3,$4)',
    [asset.id, req.body.ticketId, req.body.type, req.body.notes],
  );
  const { rows } = await pool().query(
    'SELECT id,history_type AS type,notes,created_at AS "createdAt" FROM asset_service_history WHERE id=$1',
    [insertId],
  );
  res.status(201).json(rows[0]);
}
async function reviews(req,res){res.json(await require('../../services/reviewService').admin());}
module.exports = {
  tickets,
  ticket,
  updateTicket,
  technicians,
  createTechnician,
  technician,
  updateTechnician,
  assets,
  createAsset,
  asset,
  updateAsset,
  updateAssetQr,
  addAssetHistory,
  reviews,
};
