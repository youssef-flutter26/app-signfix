const router = require('express').Router();
const delhivery = require('../services/delhiveryService');
const { authenticate, authorize } = require('../middleware/auth');
router.use(authenticate, authorize('super_admin','admin','sales_manager'));
// Live lookup of any AWB without linking it to an order.
router.get('/track/:waybill', async (req, res) => {
  if (!/^[A-Za-z0-9]{6,40}$/.test(req.params.waybill)) return res.status(422).json({ error: 'Enter a valid Delhivery waybill (AWB) number' });
  res.json(await delhivery.trackWaybill(req.params.waybill));
});
// Refreshes every undelivered shipment whose cache is stale (cron/admin trigger).
router.post('/sync', async (_req, res) => res.json(await delhivery.syncActiveShipments()));
module.exports = router;
