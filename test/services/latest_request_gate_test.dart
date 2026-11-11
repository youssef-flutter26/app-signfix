import 'package:flutter_test/flutter_test.dart';
import 'package:signfix_app/services/latest_request_gate.dart';

void main() {
  test('only the newest calculator request remains valid', () {
    final gate = LatestRequestGate();
    final firstRequest = gate.begin();
    final secondRequest = gate.begin();

    expect(gate.isLatest(firstRequest), isFalse);
    expect(gate.isLatest(secondRequest), isTrue);
  });

  test('input changes invalidate an in-flight calculator request', () {
    final gate = LatestRequestGate();
    final request = gate.begin();

    gate.invalidate();

    expect(gate.isLatest(request), isFalse);
  });
}
