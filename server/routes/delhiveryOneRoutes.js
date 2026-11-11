const router = require("express").Router();
const { z } = require("zod");
const delhiveryOne = require("../services/delhiveryOneService");
const validate = require("../middleware/validate");
const { authenticate, authorize } = require("../middleware/auth");

// Delhivery One gateway proxies. These are NEW endpoints; existing order and
// shipment routes are untouched.
router.use(authenticate, authorize("super_admin", "admin", "sales_manager"));

// Prepaid wallet balance for the configured Delhivery One client.
router.get("/wallet", async (_req, res) => {
  res.json(await delhiveryOne.getWallet());
});

const rateRequest = z.object({
  origin_pin: z
    .string()
    .trim()
    .regex(/^\d{6}$/, "Origin must be a 6-digit PIN code"),
  destination_pin: z
    .string()
    .trim()
    .regex(/^\d{6}$/, "Destination must be a 6-digit PIN code"),
  shipping_mode: z.enum(["SURFACE", "EXPRESS"]),
  weight: z.coerce.number().positive(),
  weight_unit: z.enum(["GM", "KG"]).default("GM"),
  payment_mode: z.enum(["PREPAID", "COD"]).default("PREPAID"),
  cod_amount: z.coerce.number().nonnegative().optional(),
  // The gateway rejects dimension-less requests ("Length is a required field").
  length: z.coerce.number().positive(),
  breadth: z.coerce.number().positive(),
  height: z.coerce.number().positive(),
  packaging_type: z.enum(["FLYER", "BOX", "CUSTOM"]).optional(),
  shipment_type: z.enum(["FORWARD", "REVERSE"]).default("FORWARD"),
});

// B2C rate estimates for up to 4 shipments in one call.
router.post(
  "/rates",
  validate(z.object({ requests: z.array(rateRequest).min(1).max(4) })),
  async (req, res) => {
    res.json(await delhiveryOne.getRate(req.body.requests));
  },
);

module.exports = router;
