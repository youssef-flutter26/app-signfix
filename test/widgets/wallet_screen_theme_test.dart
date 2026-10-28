import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signfix_app/core/app_theme.dart';
import 'package:signfix_app/screens/profile/wallet_screen.dart';
import 'package:signfix_app/services/api_client.dart';

class _WalletApi extends ApiClient {
  _WalletApi() : super(baseUrl: 'https://example.test/api');

  @override
  Future<Map<String, dynamic>> wallet() async => {
        'balance': 500,
        'totalCashbackEarned': 200,
        'transactions': [
          {
            'type': 'cashback_credit',
            'amount': 200,
            'status': 'successful',
            'description': 'Cashback Received',
            'createdAt': '2026-10-27T12:00:00Z',
            'previousBalance': 300,
            'balanceAfter': 500,
          },
        ],
      };
}

void main() {
  testWidgets('customer wallet uses the workbook light surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: WalletScreen(api: _WalletApi()),
      ),
    );
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));

    expect(scaffold.backgroundColor, AppColors.softGray);
    expect(appBar.backgroundColor, AppColors.appBar);
    expect(appBar.foregroundColor, AppColors.navy);
    expect(find.text('Available Balance'), findsOneWidget);
    expect(find.text('Wallet Transaction History'), findsOneWidget);
    expect(find.text('Cashback Received'), findsOneWidget);

    final balanceText = tester.widget<Text>(find.text('Available Balance'));
    expect(balanceText.style?.color, AppColors.textSecondary);
    final transactionTitle = tester.widget<Text>(
      find.text('Cashback Received'),
    );
    expect(transactionTitle.style?.color, AppColors.navy);
  });
}
