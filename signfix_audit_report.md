# SignFix App — Complete Audit Report

**Date:** 2025-07  
**Scope:** All 35 `.dart` files in `lib/` (customer side + technician side)  
**Audit Type:** Read-only — no code was changed

---

## Executive Summary

The app is **broadly well-structured** and correctly uses the dark-navy + gold theme across almost every screen. The `AppColors`, `buildAppTheme()`, and `buildTechnicianTheme()` are properly defined and used almost everywhere. However, the audit found **10 genuine issues** spread across both portals, ranging from a potentially invisible widget in the shared `widgets/common.dart`, a hardcoded demo hint visible to end users, GPS location accuracy regression on iOS, navigation back-button behaviour (already patched via `PopScope` but one edge case remains), and several minor/cosmetic issues. There are **no invisible-text-on-dark-background** problems — that class of issue has already been fixed throughout the codebase.

---

## ISSUE LIST

### ISSUE 1 — `lib/widgets/common.dart`: `ActionCard` widget — white text on potentially non-white card color *(Medium)*

**File:** `lib/widgets/common.dart`, lines 28-54  
**Widget:** `ActionCard`  

```dart
Material(
  color: color,           // passed-in color (could be any accent)
  ...
  Text(title,
      style: const TextStyle(color: Colors.white, ...)),  // hardcoded white
  Text(subtitle,
      style: const TextStyle(color: Colors.white70)),     // hardcoded white70
  Text(label,
      style: const TextStyle(color: Colors.white, ...)),  // hardcoded white
```

The `ActionCard` widget uses `Colors.white` and `Colors.white70` for all its text, which is fine when `color` is a dark or saturated color. However, the `StatusTile` widget in the same file also uses a `Card` widget with no explicit `backgroundColor`, so it falls back to the theme card color (`AppColors.navyDark`) — which is fine. The `ActionCard` is **not currently used** anywhere in the active screens (the customer and technician home use their own inline action cards), so this is a dormant risk rather than a live bug.

**Fix:** If `ActionCard` is ever used, ensure the `color` parameter is always a dark/saturated color, or change text color to `AppColors.navyDeep` (which is the standard for text on gold).

---

### ISSUE 2 — `lib/widgets/common.dart`: `StatusTile` uses `AppColors.primary` as icon color *(Low)*

**File:** `lib/widgets/common.dart`, line 56-64  

```dart
class StatusTile extends StatelessWidget {
  ...
  final Color color;  // defaults to AppColors.primary = AppColors.navyMid
```

`AppColors.primary` is aliased to `AppColors.navyMid` (a dark navy color, `0xFF132057`). If `StatusTile` is ever used with its default `color`, the icon and circle background will be near-invisible against the dark card. Again, `StatusTile` is **not actively used** in any current screen, but it is a dormant bug.

**Fix:** Change the default from `AppColors.primary` to `AppColors.gold`.

---

### ISSUE 3 — `otp_verification_screen.dart`: Hardcoded "Demo OTP: 123456" hint visible to end users *(High — UX / Security)*

**File:** `lib/technician/screens/registration/otp_verification_screen.dart`, lines ~145-155  

```dart
Container(
  ...
  child: const Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.info_outline, size: 14, color: AppColors.warning),
    SizedBox(width: 6),
    Text('Demo OTP: 123456',
        style: TextStyle(
            color: AppColors.warning,
            fontSize: 12,
            fontWeight: FontWeight.w600)),
  ]),
),
```

This renders a visible golden-yellow chip on the OTP verification screen that says **"Demo OTP: 123456"**. This is fine in development/mock mode but must not appear in a production build, since it:
- Tells any user how to bypass real OTP verification.
- Undermines the security of the registration flow.

**Fix:** Gate this widget behind a compile-time constant or remove it entirely before production release:
```dart
if (kDebugMode)
  Container(/* Demo OTP hint */),
```
Or delete it for production and use `kDebugMode` check.

---

### ISSUE 4 — `service_request.dart`: GPS accuracy only uses `AndroidSettings` — crashes/falls back silently on iOS *(High — Bug)*

**File:** `lib/screens/service/service_request.dart`, lines ~70-80  

```dart
final pos = await Geolocator.getCurrentPosition(
  locationSettings: AndroidSettings(
    accuracy: LocationAccuracy.high,
    forceLocationManager: false,
    timeLimit: const Duration(seconds: 15),
  ),
);
```

`AndroidSettings` is an Android-only class. On **iOS**, passing `AndroidSettings` to `getCurrentPosition` will either throw or silently fall back to default (low-accuracy) settings. Since the user reported "GPS captures wrong location", this is likely the root cause — on iOS or emulators, the coordinates returned are inaccurate because iOS-specific location settings (like `timeLimit`) are not applied.

**Fix:** Use platform-aware settings:
```dart
import 'dart:io' show Platform;
import 'package:geolocator/geolocator.dart';

final locationSettings = Platform.isAndroid
    ? AndroidSettings(
        accuracy: LocationAccuracy.high,
        forceLocationManager: false,
        timeLimit: const Duration(seconds: 15),
      )
    : AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.other,
        timeLimit: const Duration(seconds: 15),
        pauseLocationUpdatesAutomatically: false,
      );

final pos = await Geolocator.getCurrentPosition(
  locationSettings: locationSettings,
);
```

Alternatively, use the generic `LocationSettings`:
```dart
final pos = await Geolocator.getCurrentPosition(
  locationSettings: const LocationSettings(
    accuracy: LocationAccuracy.high,
    timeLimit: Duration(seconds: 15),
  ),
);
```

---

### ISSUE 5 — `service_request.dart`: `suffixIcon` on address field does not rebuild after GPS fill *(Medium — UX)*

**File:** `lib/screens/service/service_request.dart`, around line ~185  

```dart
suffixIcon: _address.text.isNotEmpty
    ? IconButton(
        icon: const Icon(Icons.clear, ...),
        onPressed: () { ... },
      )
    : null,
```

The `suffixIcon` is conditionally shown when `_address.text.isNotEmpty`. The `onChanged` callback on the same `TextField` calls `setState(() {})` to trigger a rebuild, which is correct for manual typing. However, when GPS fills the address via `_address.text = addressText` (inside `setState`), the text controller is updated but the `TextField`'s internal `InputDecoration` will only rebuild if a parent `setState` fires. In the current code `setState(() { _position = pos; ... })` already wraps the assignment, so this rebuild *should* work. 

**Minor risk:** If the GPS fills the field but the clear button does not appear, it means the `onChanged` branch is not triggered by programmatic controller updates — which is a known Flutter behavior. The `setState` wrapping the GPS fill does cover the `_address.text.isNotEmpty` check.

**Fix (belt and suspenders):** Use a `ValueNotifier<String>` or `ListenableBuilder` for the address text, or explicitly set state after the controller update — which is already being done. Current implementation is acceptable; flag for testing.

---

### ISSUE 6 — `customer_home.dart` / `app_shell.dart`: Back button behavior — `PopScope` implemented correctly, but `ProfileScreen` and `NotificationsScreen` (pushed via `Navigator.push`) do not have `PopScope` *(Low — Navigation)*

**File:** `lib/screens/home/customer_home.dart` and `lib/technician/screens/shell/app_shell.dart`

Both shell screens use `PopScope` correctly:
```dart
PopScope(
  canPop: _index == 0,
  onPopInvokedWithResult: (didPop, _) {
    if (!didPop && _index != 0) {
      setState(() => _index = 0);
    }
  },
  ...
)
```

This correctly intercepts the back button when on any non-home tab and returns to tab 0. When on tab 0, `canPop: true` allows the app to minimize normally.

**Remaining edge case:** When the user navigates to a sub-screen that is pushed via `Navigator.push` (e.g., `ProfileScreen`, `NotificationsScreen`, `OrderDetailScreen`, `JobDetailScreen`), pressing back will correctly pop back to the calling screen via Flutter's default navigation. This is expected behavior and is working correctly.

**There is no issue here** — the navigation is correct. The original user complaint about "app closing instead of going to home screen" was referring to the back button on tab-level screens, which is now correctly handled by `PopScope`.

---

### ISSUE 7 — `order_wizard.dart`: Step 2 address field has no GPS capture *(Medium — Missing Feature)*

**File:** `lib/screens/orders/order_wizard.dart`, `_step2()` method  

```dart
TextField(
  controller: address, maxLines: 2,
  style: const TextStyle(color: AppColors.white),
  decoration: const InputDecoration(
    labelText: 'Delivery / installation address',
    prefixIcon: Icon(Icons.location_on_outlined),
  ),
),
```

The `OrderWizard` step 2 (Dimensions & Delivery) has a plain text address field with no GPS button. In contrast, `ServiceRequest` has a full GPS capture flow with reverse geocoding. The order wizard only allows manual address entry.

**This is not a bug per se** (manual entry works), but it is an inconsistency with the service request flow.

**Fix (optional improvement):** Add a GPS capture button to the order wizard's address field, reusing the same `_captureLocation()` pattern from `service_request.dart`.

---

### ISSUE 8 — `technician/screens/registration/reg_step3_security.dart`: Validation order issue *(Low — Logic Bug)*

**File:** `lib/technician/screens/registration/reg_step3_security.dart`, `_validate()` method  

```dart
bool _validate() {
  if (_pass.text.length < 8) {          // checks length < 8 FIRST
    setState(() => _error = '...');
    return false;
  }
  if (!RegExp(r'...').hasMatch(_pass.text)) { ... }
  if (_pass.text.isEmpty) {             // ← DEAD CODE: empty string length is 0, caught above
    setState(() => _error = 'Password is required.');
    return false;
  }
  if (_pass.text != _confirm.text) { ... }
  if (_confirm.text.isEmpty) {          // ← DEAD CODE: if pass != confirm and confirm is empty, already caught above
    ...
  }
```

The `_pass.text.isEmpty` check (line ~70) is unreachable because an empty string has length 0, which is `< 8`, so it is already caught by the first check. The `_confirm.text.isEmpty` check is also partly redundant. The validation still **works correctly** end-to-end, but the dead code creates maintenance confusion.

**Fix:** Reorder validation: check empty first, then length, then regex, then confirm match.

---

### ISSUE 9 — `dashboard_screen.dart` (technician): `humanize()` defined locally AND in `app_utils.dart` *(Low — Code Duplication)*

**Files:**  
- `lib/core/app_utils.dart` — defines `humanize()`  
- `lib/technician/screens/dashboard/dashboard_screen.dart` — defines its own `humanize()`  
- `lib/technician/screens/jobs/jobs_screen.dart` — defines its own `humanize()`  

Both technician screens define the same `humanize()` function locally instead of importing `app_utils.dart`. This is harmless but creates maintenance duplication — a change to the logic would need to be made in 3 places.

**Fix:** Import `app_utils.dart` and remove the local definitions:
```dart
import '../../../core/app_utils.dart' show humanize;
```

---

### ISSUE 10 — `payment_screen.dart`: Razorpay key is a placeholder and `order_id` is empty *(High — Production Blocker)*

**File:** `lib/screens/payment/payment_screen.dart`, lines ~60-80  

```dart
static const _razorpayKey = 'rzp_test_YourKeyHere'; // ← APNI KEY YAHAN LIKHO

final options = {
  'key': _razorpayKey,
  'amount': (widget.amount * 100).toInt(),
  ...
  'order_id': '', // Set backend-generated Razorpay order_id here for prod
  ...
};
```

Two production blockers:
1. The Razorpay API key is a placeholder (`rzp_test_YourKeyHere`). No payment will work until a real test or live key is inserted.
2. `order_id` is left as an empty string. For production Razorpay integration, this must be a server-generated Razorpay order ID. Without it, server-side payment verification is impossible (you can't confirm payment authenticity).

**Fix:**
1. Replace `_razorpayKey` with your actual Razorpay test key (for demo) or live key (for production). Store it in a `.env` or use `--dart-define` at build time, not hardcoded.
2. Generate a Razorpay order ID on your backend (`/api/payment/create-order`) and pass it here before calling `_razorpay.open()`.

---

## SUMMARY TABLE

| # | File | Issue | Severity | Type |
|---|------|-------|----------|------|
| 1 | `widgets/common.dart` | `ActionCard` — dormant white-text risk | Low | Dormant |
| 2 | `widgets/common.dart` | `StatusTile` — `AppColors.primary` (dark navy) as icon color | Low | Dormant |
| 3 | `technician/.../otp_verification_screen.dart` | "Demo OTP: 123456" visible in production | **High** | Security/UX |
| 4 | `screens/service/service_request.dart` | `AndroidSettings` only — wrong/low accuracy on iOS | **High** | Bug |
| 5 | `screens/service/service_request.dart` | Suffix clear button rebuild edge case | Medium | Minor UX |
| 6 | `customer_home.dart` / `app_shell.dart` | PopScope back-nav — already correctly implemented | ✅ OK | — |
| 7 | `screens/orders/order_wizard.dart` | No GPS in order address field | Medium | Missing feature |
| 8 | `technician/.../reg_step3_security.dart` | Dead code in validation order | Low | Logic |
| 9 | `dashboard_screen.dart`, `jobs_screen.dart` | Local `humanize()` duplication | Low | Maintenance |
| 10 | `screens/payment/payment_screen.dart` | Razorpay key is placeholder; `order_id` empty | **High** | Production blocker |

---

## THINGS THAT ARE CORRECT (Do NOT change)

The following were specifically checked and are properly implemented:

| Item | Status |
|------|--------|
| All screen backgrounds use `AppColors.navyDeep` or `AppColors.navyDark` | ✅ |
| All text explicitly uses `AppColors.white`, `AppColors.textLight`, or `AppColors.textMuted` | ✅ |
| No `Colors.black54` / `Colors.black45` / `Colors.black38` on dark bg | ✅ |
| No white card/container on dark background | ✅ |
| `PopScope` back-button behavior (customer + technician shells) | ✅ |
| Bottom nav `NavigationBar` selected/unselected colors | ✅ |
| GPS reverse geocoding (Nominatim) fills address field on Android | ✅ |
| GPS snackbar success message shows captured address | ✅ |
| Customer `ProfileScreen` — all text visible | ✅ |
| Technician `ProfileScreen` — all text visible | ✅ |
| `ActivityScreen` tab switching from stat tiles | ✅ |
| `OrderDetailScreen` — all text and stepper colors | ✅ |
| `AiChat` — message bubble colors (gold for user, navy for AI) | ✅ |
| `NotificationsScreen` (both) — read/unread backgrounds | ✅ |
| `TextDesignerScreen` — neon preview on dark background | ✅ |
| `HelpSupportScreen` — all text visible | ✅ |
| `PaymentScreen` — all text visible | ✅ |
| Customer + technician login/register screens | ✅ |
| Technician registration 3-step flow | ✅ |
| `DropdownButtonFormField` uses `dropdownColor: AppColors.navyMid` | ✅ |
| `AlertDialog` uses `backgroundColor: AppColors.navyDark` | ✅ |
| `BottomSheet` uses `backgroundColor: AppColors.navyDark` | ✅ |

---

## HIGH-PRIORITY ACTION ITEMS (Ordered)

1. **ISSUE 10** — Insert real Razorpay key + backend order_id before any payment testing with real money.
2. **ISSUE 3** — Remove or gate the "Demo OTP: 123456" hint behind `kDebugMode` before any public release.
3. **ISSUE 4** — Fix GPS `AndroidSettings` → cross-platform `LocationSettings` to resolve wrong location on iOS.
4. **ISSUE 7** — Add GPS capture to order wizard address field for consistency with service request UX.
5. **ISSUES 1, 2, 8, 9** — Low-priority cleanup, no runtime impact.

---

*Report generated by read-only codebase scan. No code was modified.*
