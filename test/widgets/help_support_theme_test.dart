import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signfix_app/core/app_theme.dart';
import 'package:signfix_app/screens/support/help_support_screen.dart';

void main() {
  testWidgets('help and support uses light workbook surfaces and readable text',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const HelpSupportScreen(),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(scaffold.backgroundColor, AppColors.softGray);
    expect(appBar.backgroundColor, AppColors.appBar);
    expect(appBar.foregroundColor, AppColors.navy);

    final supportTitle = tester.widget<Text>(find.text('SignFix Support'));
    expect(supportTitle.style?.color, AppColors.navy);
    final contactTitle = tester.widget<Text>(find.text('Call Us'));
    expect(contactTitle.style?.color, AppColors.navy);
    final sectionTitle = tester.widget<Text>(find.text('Contact Us'));
    expect(sectionTitle.style?.color, AppColors.navy);

    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();
    final answer = tester.widget<Text>(
      find.text(
        'Go to the Order tab, select your sign type, enter dimensions and material, get an instant estimate, then submit your order.',
      ),
    );
    expect(answer.style?.color, AppColors.textBody);
  });
}
