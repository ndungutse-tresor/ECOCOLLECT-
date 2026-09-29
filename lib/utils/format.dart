import 'package:intl/intl.dart';

String formatKg(double kg) {
  if (kg >= 1000) return '${trimDecimals(kg / 1000, 1)} t';
  if (kg >= 100) return '${kg.round()} kg';
  if (kg >= 10) return '${trimDecimals(kg, 1)} kg';
  return '${trimDecimals(kg, 2)} kg';
}

/// Fixed decimals without trailing zeros: 3.50 -> "3.5", 2.00 -> "2".
String trimDecimals(double value, int decimals) {
  var text = value.toStringAsFixed(decimals);
  if (text.contains('.')) {
    text = text.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return text;
}

String formatNumber(num value) => NumberFormat.decimalPattern().format(value);

/// Rwandan francs, e.g. "RWF 3,000".
String formatRwf(num amount) => 'RWF ${formatNumber(amount)}';

String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(meters < 10000 ? 1 : 0)} km';
}

String formatDate(DateTime date) => DateFormat('MMM d, yyyy').format(date);

String formatDateTime(DateTime date) =>
    DateFormat('MMM d, yyyy · HH:mm').format(date);

String formatShortDay(DateTime date) => DateFormat('EEE d MMM').format(date);

String timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return DateFormat('MMM d').format(date);
}

/// Kinyarwanda greeting for the time of day.
String greetingForNow() {
  final hour = DateTime.now().hour;
  return hour < 12 ? 'Mwaramutse' : 'Mwiriwe';
}

/// Accepts Rwandan mobile numbers such as 0788123456 or +250 788 123 456.
bool isValidRwandaPhone(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  return RegExp(r'^(250|0)?7\d{8}$').hasMatch(digits);
}

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}
