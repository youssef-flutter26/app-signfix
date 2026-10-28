import 'package:intl/intl.dart';

String humanize(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String money(dynamic value, {String symbol = '₹'}) {
  final amount =
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  final decimals = amount == amount.roundToDouble() ? 0 : 2;
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: symbol,
    decimalDigits: decimals,
  ).format(amount);
}

double orderMinimumShortfall(num total, {num minimum = 2500}) =>
    (minimum - total).clamp(0, double.infinity).toDouble();

bool requiresPromotionalOrderMinimum(String? bannerId) =>
    const {'home_banner_2', 'home_banner_3'}.contains(bannerId);
