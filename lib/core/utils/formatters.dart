import 'package:intl/intl.dart';
import 'currency.dart';

String formatCurrency(num amount, {String currencyCode = 'GHS'}) {
  final currency = currencyByCode(currencyCode);
  final converted = convertFromGhs(amount, currency.code);
  final formatter = NumberFormat.currency(
    symbol: currency.code == 'GHS' ? 'GHS ' : '${currency.symbol} ',
    decimalDigits: 2,
  );
  return formatter.format(converted);
}

String formatDate(DateTime date) {
  return DateFormat('dd MMM, yyyy').format(date);
}
