import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signfix_app/core/app_theme.dart';
import 'package:signfix_app/screens/activity/activity_screen.dart';
import 'package:signfix_app/screens/service/service_request.dart';
import 'package:signfix_app/services/api_client.dart';

class _ThemeTestApi extends ApiClient {
  _ThemeTestApi() : super(baseUrl: 'https://example.test/api');

  @override
  Future<List<dynamic>> orders() async => [];

  @override
  Future<List<dynamic>> services() async => [];

  @override
  Future<List<dynamic>> getQuotations() async => [];

  @override
  Future<List<dynamic>> getPayments() async => [];
}

void main() {
  testWidgets('service request heading is visible on the light page', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: ServiceRequest(api: _ThemeTestApi())),
      ),
    );

    final title = tester.widget<Text>(find.text('Request a service'));
    expect(title.style?.color, AppColors.navy);
  });

  testWidgets('service category dropdown uses readable light menu colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: ServiceRequest(api: _ThemeTestApi())),
      ),
    );

    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(dropdown.initialValue, 'LED Problem');
    expect(dropdown.decoration.labelText, 'Problem category');

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    final category = tester.widget<Text>(find.text('Electrical Issue').last);
    expect(category.style?.color, AppColors.navy);
  });

  testWidgets('activity title and tabs use the workbook surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ActivityScreen(api: _ThemeTestApi()),
      ),
    );
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));

    expect(scaffold.backgroundColor, AppColors.softGray);
    expect(appBar.backgroundColor, AppColors.appBar);
    expect(appBar.foregroundColor, AppColors.navy);
    expect(tabBar.labelColor, AppColors.goldDark);
    expect(tabBar.unselectedLabelColor, AppColors.midGray);
    expect(find.text('My Activity'), findsOneWidget);
    expect(find.text('My Orders'), findsOneWidget);
    expect(find.text('My Services'), findsOneWidget);
  });
}
