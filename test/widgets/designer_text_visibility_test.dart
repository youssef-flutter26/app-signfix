import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signfix_app/core/app_theme.dart';
import 'package:signfix_app/screens/profile/profile_screen.dart';
import 'package:signfix_app/screens/orders/signage_designer_screen.dart';
import 'package:signfix_app/screens/orders/text_designer_screen.dart';
import 'package:signfix_app/services/api_client.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'https://example.test/api');

  @override
  Future<List<Map<String, dynamic>>> getSavedAddresses() async => [];

  @override
  Future<Map<String, dynamic>> getProfile() async => {
        'name': 'Customer',
        'email': 'customer@example.com',
        'phone': '03001234567',
        'address': 'Lahore',
        'memberSince': '2025',
        'totalOrders': 1,
        'totalServices': 0,
        'walletBalance': 0,
      };
}

void main() {
  testWidgets('text designer input is readable on the themed input surface',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const TextDesignerScreen(),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField).first);

    expect(field.style?.color, AppColors.textBody);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(scaffold.backgroundColor, AppColors.softGray);
    expect(appBar.backgroundColor, AppColors.appBar);
    expect(appBar.foregroundColor, AppColors.navy);
  });

  testWidgets('sign preview background keeps every selected text color legible',
      (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const TextDesignerScreen(),
      ),
    );

    Container preview() => tester.widget<Container>(
          find.byKey(const ValueKey('sign-text-preview')),
        );

    expect(
      (preview().decoration! as BoxDecoration).color,
      AppColors.white,
    );

    final navySwatch =
        find.byKey(ValueKey('designer-color-${AppColors.navy.toARGB32()}'));
    final navyCheck = tester.widget<Icon>(
      find.descendant(
        of: navySwatch,
        matching: find.byIcon(Icons.check_rounded),
      ),
    );
    expect(navyCheck.color, AppColors.white);

    await tester.tap(navySwatch);
    await tester.pump();

    expect(
      (preview().decoration! as BoxDecoration).color,
      AppColors.white,
    );
    final previewText = tester.widget<Text>(find.text('YOUR TEXT HERE'));
    expect(previewText.style?.color, AppColors.navy);

    final goldSwatch =
        find.byKey(ValueKey('designer-color-${AppColors.gold.toARGB32()}'));
    await tester.tap(goldSwatch);
    await tester.pump();

    expect(
      (preview().decoration! as BoxDecoration).color,
      AppColors.navy,
    );
    final goldCheck = tester.widget<Icon>(
      find.descendant(
        of: goldSwatch,
        matching: find.byIcon(Icons.check_rounded),
      ),
    );
    expect(goldCheck.color, AppColors.navy);
  });

  testWidgets('customer profile uses the workbook surfaces and readable fields',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ProfileScreen(api: _FakeApiClient(), onLogout: () {}),
      ),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(scaffold.backgroundColor, AppColors.softGray);
    expect(appBar.backgroundColor, AppColors.appBar);
    expect(appBar.foregroundColor, AppColors.navy);

    await tester.tap(find.text('Edit'));
    await tester.pump();
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields, hasLength(3));
    expect(
      fields.every((field) => field.style?.color == AppColors.charcoal),
      isTrue,
    );
  });

  testWidgets('signage designer input is readable on the themed input surface',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: SignageDesignerScreen(api: _FakeApiClient()),
      ),
    );

    final field = tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.controller?.text == 'SIGNFIX STUDIOS',
      ),
    );

    expect(field.style?.color, AppColors.textBody);
  });

  testWidgets('signage text stays visible against a matching dark backing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: SignageDesignerScreen(api: _FakeApiClient()),
      ),
    );

    await tester.tap(
      find.byKey(
        ValueKey('signage-text-color-${AppColors.navy.toARGB32()}'),
      ),
    );
    await tester.pump();

    final visibleText = tester.widget<Text>(
      find.byKey(const ValueKey('sign-preview-text')),
    );
    expect(visibleText.style?.color, AppColors.navy);

    final outline = tester.widget<Text>(
      find.byKey(const ValueKey('sign-preview-outline')),
    );
    final outlinePaint = outline.style?.foreground;
    expect(outlinePaint, isNotNull);
    expect(outlinePaint!.color.toARGB32(), AppColors.white.toARGB32());

    await tester.tap(
      find.byKey(const ValueKey('signage-backing-acp_brushed_gold')),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(
        ValueKey('signage-text-color-${AppColors.gold.toARGB32()}'),
      ),
    );
    await tester.pump();

    final goldOnGoldOutline = tester.widget<Text>(
      find.byKey(const ValueKey('sign-preview-outline')),
    );
    expect(
      goldOnGoldOutline.style?.foreground?.color.toARGB32(),
      AppColors.navy.toARGB32(),
    );
    expect(tester.takeException(), isNull);
  });
}
