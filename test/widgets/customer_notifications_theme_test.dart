import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signfix_app/core/app_theme.dart';
import 'package:signfix_app/screens/notifications/notifications_screen.dart';
import 'package:signfix_app/services/api_client.dart';

class _NotificationsApi extends ApiClient {
  _NotificationsApi() : super(baseUrl: 'https://example.test/api');

  @override
  Future<List<dynamic>> notifications() async => [];
}

void main() {
  testWidgets('customer notifications app bar uses the workbook palette', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: NotificationsScreen(api: _NotificationsApi()),
      ),
    );
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, AppColors.appBar);
    expect(appBar.foregroundColor, AppColors.navy);
    expect(find.text('Notifications'), findsOneWidget);

    final markAllRead = tester.widget<Text>(find.text('Mark all read'));
    expect(markAllRead.style?.color, AppColors.goldDark);
  });
}
