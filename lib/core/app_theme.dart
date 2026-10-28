import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SignFix Brand Colors  (from official brand palette — SignFix-Color-Theme)
//  60% Soft Gray / White  |  30% Navy  |  10% Gold
// ─────────────────────────────────────────────────────────────────────────────
abstract final class AppColors {
  static Color signPreviewBackground(Color textColor) {
    final textLuminance = textColor.computeLuminance();
    double contrastAgainst(Color background) {
      final backgroundLuminance = background.computeLuminance();
      final lighter = backgroundLuminance > textLuminance
          ? backgroundLuminance
          : textLuminance;
      final darker = backgroundLuminance > textLuminance
          ? textLuminance
          : backgroundLuminance;
      return (lighter + 0.05) / (darker + 0.05);
    }

    return contrastAgainst(white) >= contrastAgainst(navy) ? white : navy;
  }

  static Color? signPreviewOutline(Color textColor, Color backgroundColor) {
    double contrast(Color first, Color second) {
      final firstLuminance = first.computeLuminance();
      final secondLuminance = second.computeLuminance();
      final lighter =
          firstLuminance > secondLuminance ? firstLuminance : secondLuminance;
      final darker =
          firstLuminance > secondLuminance ? secondLuminance : firstLuminance;
      return (lighter + 0.05) / (darker + 0.05);
    }

    if (contrast(textColor, backgroundColor) >= 4.5) return null;
    return contrast(white, backgroundColor) >= contrast(navy, backgroundColor)
        ? white
        : navy;
  }

  // ── Primary ───────────────────────────────────────────────────────────────
  static const navy = Color(0xFF0F1B3D); // Main brand: headers, nav, footer
  static const gold = Color(0xFFF5A800); // Accent: buttons, highlights, CTAs
  static const white = Color(0xFFFFFFFF); // Clean backgrounds, text on dark

  // ── Secondary ─────────────────────────────────────────────────────────────
  static const navyDeep = Color(0xFF1C2F5E); // Cards, hover states  (Deep Blue)
  static const goldDark = Color(0xFFD48800); // Button hover / pressed
  static const goldLight = Color(0xFFFFC93C); // Gradients and highlights
  static const goldPressed = Color(0xFFB87500);

  // ── Neutral ───────────────────────────────────────────────────────────────
  static const softGray = Color(0xFFF4F6FA); // Page background, sections
  static const midGray = Color(0xFF8A93A6); // Secondary text, borders
  static const charcoal = Color(0xFF1A1A1A); // Body text

  // ── Status ────────────────────────────────────────────────────────────────
  static const success = Color(0xFF2E9E5B);
  static const danger = Color(0xFFD64545);
  static const info = Color(0xFF2F6FDE);
  static const warning = Color(0xFFF5A800); // same as gold

  // ── Backgrounds ───────────────────────────────────────────────────────────
  static const background = softGray; // Screen / Page background
  static const cardBg = white; // Card / Surface
  static const cardBorder = Color(0xFFE3E7F0); // Card border
  static const appBar = white; // App Bar / Header
  static const drawerBg = navy; // Drawer / Sidebar bg
  static const footer = navy; // Footer
  static const scrim = Color(0x800F1B3D); // Dialog overlay (50% navy)
  static const loaderTrack =
      Color(0xFFE3E7F0); // Spinner track / progress track
  static const skeletonBase = Color(0xFFE9EDF5); // Skeleton loader base
  static const skeletonShimmer = Color(0xFFF7F9FC);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const textHeading = navy; // H1–H3
  static const textBody = charcoal; // Body text
  static const textSecondary = midGray; // Secondary / hint
  static const textPlaceholder = Color(0xFFA9B1C3);
  static const textLink = goldDark;
  static const textOnDark = white;
  static const textAccent = gold;

  // ── Input Fields ──────────────────────────────────────────────────────────
  static const inputBorder = Color(0xFFCBD2E0); // Default border
  static const inputDisabledBg = Color(0xFFEEF1F7);
  static const inputDisabledBorder = cardBorder;
  static const loaderOverlay = Color(0xB30F1B3D);

  // ── Chips / Badges ────────────────────────────────────────────────────────
  static const chipDefault = Color(0xFFE9EDF5); // Default chip bg
  static const chipSelected = gold;
  static const badge = danger; // Notification badge

  // ── Status Chips ─────────────────────────────────────────────────────────
  static const statusPendingBg = Color(0xFFFFF3D6);
  static const statusPendingText = Color(0xFFB87500);
  static const statusInProgressBg = Color(0xFFDCE8FF);
  static const statusInProgressText = info;
  static const statusCompletedBg = Color(0xFFDDF3E6);
  static const statusCompletedText = success;
  static const statusCancelledBg = Color(0xFFFBE0E0);
  static const statusCancelledText = danger;

  // ── Other ─────────────────────────────────────────────────────────────────
  static const divider = cardBorder; // Divider
  static const iconDefault = navy;
  static const iconAccent = gold;
  static const shadow = Color(0x150F1B3D); // ~8% opacity navy
  static const fab = gold; // FAB background
  static const fabIcon = navy; // FAB icon
  static const ratingStars = gold;
  static const splashBg = softGray;
  static const avatarBg = navyDeep;
  static const avatarText = gold;
  static const tooltipBg = navy;
  static const tooltipText = white;
  static const white20 = Color(0x33FFFFFF);

  static const signageColors = [gold, white, navy, navyDeep, softGray];
  static const additionalSignageColors = [
    goldDark,
    goldLight,
    charcoal,
    midGray,
    success,
    danger,
    info,
  ];

  // ── Dark Mode ─────────────────────────────────────────────────────────────
  static const darkBg = Color(0xFF0A1228);
  static const darkSurface = Color(0xFF14224A);
  static const darkBody = softGray;
  static const darkSecondary = Color(0xFFA9B1C3);
  static const darkBorder = Color(0xFF2A3A66);

  // ── Legacy aliases (keep existing screens working) ───────────────────────
  static const navyDark = navy;
  static const navyMid = navyDeep;
  static const navyLight = Color(0xFF2A3A66);
  static const navyCard = white; // cards are now white
  static const white70 = Color(0xB3FFFFFF);
  static const white54 = Color(0x8AFFFFFF);
  static const whiteSmoke = softGray;
  static const textLight =
      midGray; // Secondary text across light and dark surfaces.
  static const textMuted = midGray;
  static const primary = navy;
  static const primaryDark = Color(0xFF0A1228);
  static const accent = gold;
  static const ink = charcoal;

  // ── Job Workflow Step Colors ──────────────────────────────────────────────
  static const stepAssigned = gold;
  static const stepAccepted = goldLight;
  static const stepOnTheWay = info;
  static const stepReachedLocation = info;
  static const stepInspection = goldLight;
  static const stepWorkInProgress = goldDark;
  static const stepCompleted = success;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Material 3 Theme  —  Light Mode (brand guide)
// ─────────────────────────────────────────────────────────────────────────────
ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.navy,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.navyDeep,
    onPrimaryContainer: AppColors.white,
    primaryFixed: AppColors.navy,
    primaryFixedDim: AppColors.navyDeep,
    onPrimaryFixed: AppColors.white,
    onPrimaryFixedVariant: AppColors.white,
    secondary: AppColors.gold,
    onSecondary: AppColors.navy,
    secondaryContainer: AppColors.goldLight,
    onSecondaryContainer: AppColors.navy,
    secondaryFixed: AppColors.gold,
    secondaryFixedDim: AppColors.goldDark,
    onSecondaryFixed: AppColors.navy,
    onSecondaryFixedVariant: AppColors.navy,
    tertiary: AppColors.navyDeep,
    onTertiary: AppColors.white,
    tertiaryContainer: AppColors.softGray,
    onTertiaryContainer: AppColors.navy,
    tertiaryFixed: AppColors.navyDeep,
    tertiaryFixedDim: AppColors.navy,
    onTertiaryFixed: AppColors.white,
    onTertiaryFixedVariant: AppColors.white,
    error: AppColors.danger,
    onError: AppColors.white,
    errorContainer: AppColors.statusCancelledBg,
    onErrorContainer: AppColors.statusCancelledText,
    surface: AppColors.white,
    onSurface: AppColors.charcoal,
    surfaceDim: AppColors.softGray,
    surfaceBright: AppColors.white,
    surfaceContainerLowest: AppColors.white,
    surfaceContainerLow: AppColors.softGray,
    surfaceContainer: AppColors.white,
    surfaceContainerHigh: AppColors.softGray,
    surfaceContainerHighest: AppColors.softGray,
    onSurfaceVariant: AppColors.midGray,
    outline: AppColors.inputBorder,
    outlineVariant: AppColors.cardBorder,
    shadow: AppColors.shadow,
    scrim: AppColors.scrim,
    inverseSurface: AppColors.navy,
    onInverseSurface: AppColors.white,
    inversePrimary: AppColors.goldLight,
    surfaceTint: AppColors.navy,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.softGray,
    canvasColor: AppColors.white,
    splashColor: AppColors.gold.withValues(alpha: .12),
    highlightColor: AppColors.gold.withValues(alpha: .08),
    focusColor: AppColors.gold.withValues(alpha: .12),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.gold,
      selectionColor: Color(0x66F5A800),
      selectionHandleColor: AppColors.gold,
    ),

    // ── AppBar ──────────────────────────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.appBar,
      foregroundColor: AppColors.navy,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.navy,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
      iconTheme: IconThemeData(color: AppColors.navy),
    ),

    // ── Bottom Navigation ───────────────────────────────────────────────────
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.white,
      indicatorColor: AppColors.gold.withValues(alpha: .15),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.gold, size: 24);
        }
        return const IconThemeData(color: AppColors.midGray, size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: AppColors.navy,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          );
        }
        return const TextStyle(color: AppColors.midGray, fontSize: 11);
      }),
      surfaceTintColor: Colors.transparent,
      elevation: 2,
    ),

    // ── Cards ───────────────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder, width: 1),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(
        color: AppColors.navy,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
      contentTextStyle: const TextStyle(color: AppColors.charcoal),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.white,
      modalBackgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: AppColors.scrim,
      showDragHandle: true,
      dragHandleColor: AppColors.midGray,
    ),

    // ── Input Fields ────────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      labelStyle: const TextStyle(color: AppColors.navy, fontSize: 14),
      hintStyle: const TextStyle(color: AppColors.textPlaceholder),
      prefixIconColor: AppColors.midGray,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gold, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.inputDisabledBorder),
      ),
      errorStyle: const TextStyle(color: AppColors.danger),
    ),

    // ── Filled / Primary Button (Gold CTA) ──────────────────────────────────
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.gold.withValues(alpha: .4);
          }
          if (states.contains(WidgetState.pressed)) {
            return AppColors.goldPressed;
          }
          if (states.contains(WidgetState.hovered)) {
            return AppColors.goldDark;
          }
          return AppColors.gold;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled)
                ? AppColors.navy.withValues(alpha: .5)
                : AppColors.navy),
        minimumSize: WidgetStateProperty.all(const Size.fromHeight(52)),
        textStyle: WidgetStateProperty.all(const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 15,
          letterSpacing: 0.4,
        )),
        shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        elevation: WidgetStateProperty.all(0),
      ),
    ),

    // ── Elevated Button (Secondary — Navy) ──────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    ),

    // ── Outlined Button ──────────────────────────────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        side: const BorderSide(color: AppColors.navy, width: 1.5),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),

    // ── Text Button ──────────────────────────────────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.goldDark),
    ),

    // ── FAB ──────────────────────────────────────────────────────────────────
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.gold,
      foregroundColor: AppColors.navy,
    ),

    // ── Chip ─────────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.chipDefault,
      selectedColor: AppColors.gold,
      labelStyle: const TextStyle(color: AppColors.navy, fontSize: 13),
      side: const BorderSide(color: AppColors.cardBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      checkmarkColor: AppColors.navy,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: AppColors.white,
      surfaceTintColor: Colors.transparent,
      textStyle: TextStyle(color: AppColors.charcoal),
    ),

    // ── Divider ───────────────────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: AppColors.cardBorder,
      thickness: 1,
    ),

    // ── SnackBar ──────────────────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.navy,
      contentTextStyle: const TextStyle(color: AppColors.white),
      actionTextColor: AppColors.gold,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // ── Drawer ────────────────────────────────────────────────────────────────
    drawerTheme: const DrawerThemeData(
      backgroundColor: AppColors.navy,
    ),

    // ── Icon ──────────────────────────────────────────────────────────────────
    iconTheme: const IconThemeData(color: AppColors.navy),

    // ── ListTile ──────────────────────────────────────────────────────────────
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.navy,
      textColor: AppColors.charcoal,
    ),

    // ── Text ──────────────────────────────────────────────────────────────────
    textTheme: const TextTheme(
      displayLarge:
          TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900),
      displayMedium:
          TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800),
      headlineLarge:
          TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800),
      headlineMedium:
          TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700),
      titleMedium:
          TextStyle(color: AppColors.navy, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: AppColors.charcoal),
      bodyMedium: TextStyle(color: AppColors.charcoal),
      bodySmall: TextStyle(color: AppColors.midGray),
      labelLarge: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700),
    ),

    // ── Progress Indicator ────────────────────────────────────────────────────
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.gold,
      linearTrackColor: AppColors.loaderTrack,
    ),

    // ── Switch ───────────────────────────────────────────────────────────────
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.gold : AppColors.white),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AppColors.gold.withValues(alpha: .4)
              : AppColors.inputBorder),
    ),

    // ── Checkbox ─────────────────────────────────────────────────────────────
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AppColors.gold
              : Colors.transparent),
      checkColor: WidgetStateProperty.all(AppColors.navy),
      side: const BorderSide(color: AppColors.midGray, width: 1.5),
    ),

    // ── Radio ────────────────────────────────────────────────────────────────
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AppColors.gold
              : AppColors.midGray),
    ),

    // ── Slider ───────────────────────────────────────────────────────────────
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.gold,
      thumbColor: AppColors.gold,
      inactiveTrackColor: AppColors.cardBorder,
    ),

    // ── Tooltip ───────────────────────────────────────────────────────────────
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: AppColors.white, fontSize: 12),
    ),

    // ── Tab Bar ───────────────────────────────────────────────────────────────
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.navy,
      unselectedLabelColor: AppColors.midGray,
      indicatorColor: AppColors.gold,
      indicatorSize: TabBarIndicatorSize.tab,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Technician portal uses the same brand system and action colors.
// ─────────────────────────────────────────────────────────────────────────────
ThemeData buildTechnicianTheme() => buildAppTheme();
