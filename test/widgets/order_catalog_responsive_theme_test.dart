import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signfix_app/core/app_theme.dart';
import 'package:signfix_app/screens/orders/power_supply_screen.dart';
import 'package:signfix_app/screens/orders/signage_designer_screen.dart';
import 'package:signfix_app/services/api_client.dart';

class _OrderScreenApi extends ApiClient {
  _OrderScreenApi() : super(baseUrl: 'https://example.test/api');
}

void main() {
  testWidgets('signage designer follows workbook colors without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: SignageDesignerScreen(api: _OrderScreenApi()),
      ),
    );
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(scaffold.backgroundColor, AppColors.softGray);
    expect(appBar.backgroundColor, AppColors.appBar);

    for (var i = 0;
        i < 8 && find.text('Total Estimated Price:').evaluate().isEmpty;
        i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();
    }
    expect(find.text('Total Estimated Price:'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('power supply catalog wraps content on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: PowerSupplyScreen(api: _OrderScreenApi()),
      ),
    );
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(scaffold.backgroundColor, AppColors.softGray);
    expect(appBar.backgroundColor, AppColors.appBar);

    const datasheet = 'Datasheet: Slim Rainproof LED Power Supply 400W';
    for (var i = 0; i < 8 && find.text(datasheet).evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();
    }
    expect(find.text(datasheet), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
