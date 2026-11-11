import 'package:flutter_test/flutter_test.dart';
import 'package:signfix_app/services/pricing_conflict_flow.dart';

void main() {
  test('recalculates, confirms, then retries once in order', () async {
    final events = <String>[];

    final result = await recoverFromPricingConflict(
      recalculate: () async {
        events.add('recalculate');
        return true;
      },
      confirmUpdatedPrice: () async {
        events.add('confirm');
        return true;
      },
      retrySubmission: () async {
        events.add('retry');
        return true;
      },
    );

    expect(result, isTrue);
    expect(events, ['recalculate', 'confirm', 'retry']);
  });

  test('does not retry when recalculation fails or price is declined',
      () async {
    var retries = 0;
    final failedCalculation = await recoverFromPricingConflict(
      recalculate: () async => false,
      confirmUpdatedPrice: () async => true,
      retrySubmission: () async {
        retries++;
        return true;
      },
    );
    final declinedPrice = await recoverFromPricingConflict(
      recalculate: () async => true,
      confirmUpdatedPrice: () async => false,
      retrySubmission: () async {
        retries++;
        return true;
      },
    );

    expect(failedCalculation, isFalse);
    expect(declinedPrice, isFalse);
    expect(retries, 0);
  });
}
