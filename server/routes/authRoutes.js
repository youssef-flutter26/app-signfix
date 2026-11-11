const router = require("express").Router();
const { z } = require("zod");
const controller = require("../controllers/authController");
const validate = require("../middleware/validate");
const { authenticate } = require("../middleware/auth");
const rateLimit = require("../middleware/rateLimit");
const authLimiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 20 });
const technicianOtpLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
});
const optionalText = (min = 0, max = 160) =>
  z.union([
    z.string().trim().min(min).max(max),
    z.literal(""),
  ]);
const optionalPincode = z.union([
  z.string().regex(/^\d{5,10}$/),
  z.literal(""),
]);
router.post(
  "/login",
  authLimiter,
  validate(
    z.object({
      email: z.string().email(),
      password: z.string().min(6),
      portal: z.enum(["admin", "customer", "technician"]).optional(),
    }),
  ),
  controller.login,
);
const strongPassword = z
  .string()
  .min(10)
  .max(72)
  .regex(/[a-z]/, "Lowercase letter required")
  .regex(/[A-Z]/, "Uppercase letter required")
  .regex(/\d/, "Number required")
  .regex(/[^A-Za-z0-9]/, "Special character required");
router.post(
  "/technician/register/send-otp",
  technicianOtpLimiter,
  validate(
    z.object({
      email: z.string().trim().email().max(190),
      mobile: z.string().trim().min(8).max(20),
    }),
  ),
  controller.sendTechnicianRegistrationOtp,
);
router.post(
  "/technician/register/verify-otp",
  authLimiter,
  validate(
    z.object({
      email: z.string().trim().email().max(190),
      otp: z.string().regex(/^\d{6}$/),
    }),
  ),
  controller.verifyTechnicianRegistrationOtp,
);
router.post(
  "/technician/register",
  authLimiter,
  validate(
    z.object({
      full_name: z.string().trim().min(2).max(120),
      email: z.string().trim().email().max(190),
      mobile: z.string().trim().min(8).max(20),
      date_of_joining: z.string().date(),
      employee_id: z.string().trim().max(80).optional(),
      work_location: z.string().trim().min(2).max(120),
      skills: z.array(z.string().trim().min(1).max(80)).max(30).default([]),
      password: strongPassword,
      registration_verification_token: z.string().min(20).max(2000),
      terms_accepted: z.literal(true),
    }),
  ),
  controller.registerTechnician,
);
router.post(
  "/register",
  validate(
    z.object({
      name: z.string().min(2).max(120),
      mobile: z.string().min(8).max(20),
      email: z.string().email(),
      password: strongPassword,
      companyName: optionalText(0, 160).default(""),
      address: optionalText(0, 255).default(""),
      city: optionalText(0, 80).default(""),
      state: optionalText(0, 80).default(""),
      pincode: optionalPincode.default(""),
    }),
  ),
  controller.register,
);
router.post(
  "/forgot-password",
  authLimiter,
  validate(z.object({ identifier: z.string().min(5) })),
  controller.forgotPassword,
);
router.post(
  "/verify-otp",
  authLimiter,
  validate(
    z.object({
      identifier: z.string().min(5).max(190),
      otp: z.string().regex(/^\d{6}$/),
      purpose: z.enum(["verify_registration", "reset_password"]),
    }),
  ),
  controller.verifyOtp,
);
router.post(
  "/reset-password",
  authLimiter,
  validate(
    z.object({ resetToken: z.string().min(10), password: strongPassword }),
  ),
  controller.resetPassword,
);
router.post(
  "/resend-registration-otp",
  authLimiter,
  validate(
    z.object({
      identifier: z.string().min(5).max(190),
      purpose: z.enum(["verify_registration", "reset_password"]).optional(),
    }),
  ),
  controller.resendRegistrationOtp,
);
router.get("/me", authenticate, controller.me);
router.post(
  "/change-password",
  authenticate,
  validate(
    z.object({
      currentPassword: z.string().min(6),
      newPassword: strongPassword,
    }),
  ),
  controller.changePassword,
);
router.post("/logout", authenticate, controller.logout);
module.exports = router;
