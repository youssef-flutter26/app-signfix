import 'package:flutter_test/flutter_test.dart';
import 'package:signfix_app/screens/activity/quotation_detail_screen.dart';

void main() {
  test('quotation actions follow the server availableActions list', () {
    expect(
      quotationActionsFor({
        'status': 'sent',
        'availableActions': ['approve', 'request_changes', 'download'],
      }),
      {'approve', 'request_changes', 'download'},
    );
    expect(
      quotationActionsFor({'status': 'approved', 'availableActions': []}),
      isEmpty,
    );
    expect(quotationActionsFor({'status': 'sent'}), isEmpty);
  });
}
