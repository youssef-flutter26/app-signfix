import 'package:flutter_test/flutter_test.dart';
import 'package:signfix_app/core/app_utils.dart';

void main() {
  test('money formats Indian grouping and preserves paise when present', () {
    expect(money(13074), '₹13,074');
    expect(money(12484.4), '₹12,484.40');
    expect(money(13074, symbol: 'Rs.'), 'Rs.13,074');
  });

  test('order minimum shortfall is zero at or above the minimum', () {
    expect(orderMinimumShortfall(2499), 1);
    expect(orderMinimumShortfall(2500), 0);
    expect(orderMinimumShortfall(3200), 0);
    expect(orderMinimumShortfall(2200, minimum: 2000), 0);
  });

  test('only promotional banners 2 and 3 require the order minimum', () {
    expect(requiresPromotionalOrderMinimum('home_banner_1'), isFalse);
    expect(requiresPromotionalOrderMinimum('home_banner_2'), isTrue);
    expect(requiresPromotionalOrderMinimum('home_banner_3'), isTrue);
    expect(requiresPromotionalOrderMinimum(null), isFalse);
  });
}
