import 'package:intl/intl.dart';

String formatCurrency(num amount) {
  final formatter = NumberFormat.currency(symbol: 'GHS ');
  return formatter.format(amount);
}

String formatDate(DateTime date) {
  return DateFormat('dd MMM, yyyy').format(date);
}
