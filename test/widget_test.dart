import 'package:flutter_test/flutter_test.dart';
import 'package:signfix_app/main.dart';

void main() {
  testWidgets('SignFix app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SignFixApp());
    expect(find.byType(SignFixApp), findsOneWidget);
  });
}
