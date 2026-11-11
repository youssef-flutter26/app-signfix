import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signfix_app/core/app_theme.dart';

void main() {
  testWidgets('themed text fields use readable dark text on white surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: TextField()),
      ),
    );

    final editableText = tester.widget<EditableText>(find.byType(EditableText));
    expect(editableText.style.color, AppColors.charcoal);
  });

  test('sign preview background has the strongest brand-palette contrast', () {
    expect(AppColors.signPreviewBackground(AppColors.navy), AppColors.white);
    expect(
        AppColors.signPreviewBackground(AppColors.charcoal), AppColors.white);
    expect(AppColors.signPreviewBackground(AppColors.gold), AppColors.navy);
    expect(AppColors.signPreviewBackground(AppColors.white), AppColors.navy);
  });

  test('sign preview adds a contrasting outline when colors are too similar',
      () {
    expect(
      AppColors.signPreviewOutline(AppColors.navy, AppColors.navy),
      AppColors.white,
    );
    expect(
      AppColors.signPreviewOutline(AppColors.gold, AppColors.white),
      AppColors.navy,
    );
    expect(
      AppColors.signPreviewOutline(AppColors.white, AppColors.navy),
      isNull,
    );
  });

  test('customer and technician portals share the workbook brand palette', () {
    final theme = buildAppTheme();
    final technicianTheme = buildTechnicianTheme();
    final buttonStyle = theme.filledButtonTheme.style!;

    expect(theme.colorScheme.primary, AppColors.navy);
    expect(theme.colorScheme.secondary, AppColors.gold);
    expect(theme.scaffoldBackgroundColor, AppColors.softGray);
    expect(theme.appBarTheme.backgroundColor, AppColors.appBar);
    expect(theme.appBarTheme.foregroundColor, AppColors.navy);
    expect(AppColors.splashBg, AppColors.softGray);
    expect(theme.colorScheme.tertiary, AppColors.navyDeep);
    expect(theme.colorScheme.onTertiary, AppColors.white);
    expect(
      AppColors.signageColors,
      [
        AppColors.gold,
        AppColors.white,
        AppColors.navy,
        AppColors.navyDeep,
        AppColors.softGray,
      ],
    );
    expect(
      AppColors.additionalSignageColors,
      [
        AppColors.goldDark,
        AppColors.goldLight,
        AppColors.charcoal,
        AppColors.midGray,
        AppColors.success,
        AppColors.danger,
        AppColors.info,
      ],
    );
    expect(buttonStyle.backgroundColor!.resolve({}), AppColors.gold);
    expect(
      buttonStyle.backgroundColor!.resolve({WidgetState.disabled}),
      AppColors.gold.withValues(alpha: .4),
    );
    expect(
      buttonStyle.foregroundColor!.resolve({WidgetState.disabled}),
      AppColors.navy.withValues(alpha: .5),
    );
    expect(technicianTheme.colorScheme, theme.colorScheme);
    expect(technicianTheme.scaffoldBackgroundColor, AppColors.softGray);
    expect(
      technicianTheme.filledButtonTheme.style!.backgroundColor!.resolve({}),
      AppColors.gold,
    );
  });
}
