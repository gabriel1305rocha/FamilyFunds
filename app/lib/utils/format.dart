import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _compact = NumberFormat.compactCurrency(locale: 'pt_BR', symbol: 'R\$');
final _percent = NumberFormat.decimalPercentPattern(locale: 'pt_BR', decimalDigits: 1);

String money(num value) => _currency.format(value);
String moneyCompact(num value) => _compact.format(value);
String percent(num value) => _percent.format(value);

String monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);
String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

String monthLabel(String month) {
  final d = DateTime.parse('$month-01');
  final s = DateFormat('MMMM yyyy', 'pt_BR').format(d);
  return s[0].toUpperCase() + s.substring(1);
}

String monthShort(String month) {
  final s = DateFormat('MMM', 'pt_BR').format(DateTime.parse('$month-01')).replaceAll('.', '');
  return s[0].toUpperCase() + s.substring(1);
}

String dayLabel(String date) {
  final d = DateTime.parse(date);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'Hoje';
  if (diff == 1) return 'Ontem';
  return DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(d);
}

String shortDate(String date) => DateFormat('dd/MM/yyyy').format(DateTime.parse(date));

double toDouble(dynamic v) => v == null ? 0 : (v as num).toDouble();
