const router = require("express").Router();
const { z } = require("zod");
const validate = require("../../middleware/validate");
const { authenticate, authorize } = require("../../middleware/auth");
const workflow = require("../../services/paymentWorkflowService");

router.use(authenticate, authorize("super_admin", "admin"));

const refundInput = z.object({
  amount: z
    .coerce
    .number()
    .positive()
    .max(9999999999)
    .refine((amount) => Math.abs(amount * 100 - Math.round(amount * 100)) < 1e-7, {
      message: "Refund amount can have at most two decimal places",
    }),
  reason: z.string().trim().min(3).max(1000),
  idempotencyKey: z.string().trim().min(8).max(120),
});

router.get("/:id/refunds", async (req, res) => {
  res.json(await workflow.listRefunds(req.params.id));
});

router.post("/:id/refunds", validate(refundInput), async (req, res) => {
  res.status(201).json(
    await workflow.createRefund(req.params.id, req.body, req.user.id),
  );
});

module.exports = router;
